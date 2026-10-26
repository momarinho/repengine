package progressionstates

import (
	"context"
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	apperrors "github.com/momarinho/rep_engine/internal/errors"
)

type Service struct {
	repo progressionStateRepo
}

func NewService(repo progressionStateRepo) *Service {
	return &Service{repo: repo}
}

type resolvedWorkflowBlock struct {
	workflowBlockConfig
	BlockKey     string
	SectionTitle string
}

type historicalBlockLogs struct {
	SessionID int
	Logs      []CompletedSetLog
}

type waveHistorySession struct {
	SessionID   int
	CompletedAt string
	Logs        []CompletedSetLog
}

var numberPattern = regexp.MustCompile(`-?\d+(?:\.\d+)?`)
var digitPattern = regexp.MustCompile(`\d+`)

func (s *Service) ApplySessionProgression(ctx context.Context, in ApplySessionProgressionInput) error {
	if in.WorkflowID <= 0 || in.UserID <= 0 || in.SessionID <= 0 {
		return nil
	}
	if len(in.Logs) == 0 {
		return nil
	}

	ownsWorkflow, err := s.repo.UserOwnsWorkflow(ctx, in.UserID, in.WorkflowID)
	if err != nil || !ownsWorkflow {
		return err
	}

	blocks, err := s.repo.ListWorkflowBlocks(ctx, in.WorkflowID)
	if err != nil {
		return err
	}
	resolvedBlocks := resolveWorkflowBlocks(blocks)

	isDeloadSession := in.IsDeload
	if !isDeloadSession {
		for _, b := range resolvedBlocks {
			if b.NodeTypeSlug == "deload" && asBool(b.Data["is_active"]) {
				isDeloadSession = true
				break
			}
		}
	}
	in.IsDeload = isDeloadSession

	existingStates, err := s.repo.ListProgressionStates(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return err
	}
	existingByKey := make(map[string]ProgressionState, len(existingStates))
	for _, state := range existingStates {
		existingByKey[state.BlockKey] = state
	}

	logsByBlock := map[int][]CompletedSetLog{}
	for _, log := range in.Logs {
		if log.WorkflowBlockID == nil || !log.Completed {
			continue
		}
		logsByBlock[*log.WorkflowBlockID] = append(logsByBlock[*log.WorkflowBlockID], log)
	}

	for _, block := range resolvedBlocks {
		blockLogs := logsByBlock[block.ID]
		if len(blockLogs) == 0 && !shouldCreateSkillStateWithoutLogs(block) {
			continue
		}

		if len(blockLogs) > 0 {
			slices.SortFunc(blockLogs, func(a, b CompletedSetLog) int {
				return a.SetIndex - b.SetIndex
			})
		}

		existingState, hasExisting := existingByKey[block.BlockKey]
		if hasExisting {
			s.syncProgressionStateWithBlock(&existingState, block)
		}
		state, ok := s.buildNextState(block, blockLogs, existingState, hasExisting, in)
		if !ok {
			continue
		}

		if _, err := s.repo.UpsertProgressionState(ctx, state); err != nil {
			return err
		}
	}

	return nil
}

func (s *Service) ListProgressionStates(ctx context.Context, in ListProgressionStatesInput) ([]ProgressionState, error) {
	if in.WorkflowID <= 0 {
		return nil, apperrors.ErrBadRequest("workflow_id is required")
	}

	ownsWorkflow, err := s.repo.UserOwnsWorkflow(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return nil, apperrors.ErrInternal()
	}
	if !ownsWorkflow {
		return nil, apperrors.ErrWorkflowNotFound()
	}

	blocks, err := s.repo.ListWorkflowBlocks(ctx, in.WorkflowID)
	if err != nil {
		return nil, apperrors.ErrInternal()
	}
	resolvedBlocks := resolveWorkflowBlocks(blocks)

	states, err := s.repo.ListProgressionStates(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return nil, apperrors.ErrInternal()
	}
	stateByKey := make(map[string]ProgressionState, len(states))
	for _, state := range states {
		stateByKey[state.BlockKey] = state
	}

	historicalLogs, err := s.repo.ListLatestCompletedLogsByBlock(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return nil, apperrors.ErrInternal()
	}
	historyByBlockID := groupHistoricalLogsByBlock(historicalLogs)

	completedLogs, err := s.repo.ListCompletedLogsByBlock(ctx, in.UserID, in.WorkflowID)
	if err != nil {
		return nil, apperrors.ErrInternal()
	}
	waveHistoryByBlockID := buildWaveHistoryByBlock(completedLogs)

	ordered := make([]ProgressionState, 0, len(states)+len(historyByBlockID))
	for _, block := range resolvedBlocks {
		state, exists := stateByKey[block.BlockKey]
		if !exists {
			history, ok := historyByBlockID[block.ID]
			if !ok {
				continue
			}
			stateInput, ok := s.buildNextState(block, history.Logs, ProgressionState{}, false, ApplySessionProgressionInput{
				UserID:     in.UserID,
				WorkflowID: in.WorkflowID,
				SessionID:  history.SessionID,
				Logs:       history.Logs,
			})
			if !ok {
				continue
			}
			synthesized := progressionStateFromUpsert(stateInput)
			synthesized.Metadata = enrichStateMetadata(block, synthesized.Metadata, waveHistoryByBlockID[block.ID])
			ordered = append(ordered, synthesized)
			continue
		}
		state.WorkflowBlockID = block.ID
		s.syncProgressionStateWithBlock(&state, block)
		state.Metadata = enrichStateMetadata(block, state.Metadata, waveHistoryByBlockID[block.ID])
		ordered = append(ordered, state)
	}

	return ordered, nil
}

func (s *Service) buildNextState(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	session ApplySessionProgressionInput,
) (UpsertProgressionStateInput, bool) {
	switch block.NodeTypeSlug {
	case "linear_progression":
		return buildLinearProgressionState(block, logs, existing, hasExisting, session), true
	case "wave":
		return buildWaveProgressionState(block, logs, existing, hasExisting, session), true
	case "exercise", "exercise_timed":
		if prog, ok := block.Data["progression"].(map[string]any); ok && prog != nil {
			progType := asString(prog["type"])
			if progType == "double" {
				return buildDoubleProgressionState(block, logs, existing, hasExisting, session), true
			}
			if progType == "linear" {
				return buildLinearProgressionState(block, logs, existing, hasExisting, session), true
			}
		}
		if !looksLikeSkillProgression(block) {
			return UpsertProgressionStateInput{}, false
		}
		return buildSkillProgressionState(block, logs, existing, hasExisting, session), true
	case "superset":
		return buildSupersetProgressionState(block, logs, existing, hasExisting, session), true
	default:
		return UpsertProgressionStateInput{}, false
	}
}

func resolveWorkflowBlocks(blocks []workflowBlockConfig) []resolvedWorkflowBlock {
	resolved := make([]resolvedWorkflowBlock, 0, len(blocks))
	currentSectionTitle := ""
	occurrences := map[string]int{}

	for _, block := range blocks {
		if block.NodeTypeSlug == "section" {
			currentSectionTitle = asString(block.Data["title"])
			if currentSectionTitle == "" {
				currentSectionTitle = fmt.Sprintf("section-%d", block.Position+1)
			}
			continue
		}

		name := blockDisplayName(block)
		keyBase := strings.ToLower(strings.TrimSpace(currentSectionTitle + "::" + block.NodeTypeSlug + "::" + name))
		occurrences[keyBase]++
		resolved = append(resolved, resolvedWorkflowBlock{
			workflowBlockConfig: block,
			BlockKey:            sanitizeKey(fmt.Sprintf("%s::%d", keyBase, occurrences[keyBase])),
			SectionTitle:        currentSectionTitle,
		})
	}

	return resolved
}

type failStep struct {
	Sets int
	Reps string
}

func parseFailSequence(s string) []failStep {
	parts := strings.Split(s, "->")
	var steps []failStep
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		// Expecting "Sets x Reps", e.g. "5x3" or "5 x 3"
		sub := strings.Split(strings.ToLower(part), "x")
		if len(sub) == 2 {
			sets, _ := strconv.Atoi(strings.TrimSpace(sub[0]))
			reps := strings.TrimSpace(sub[1])
			if sets > 0 && reps != "" {
				steps = append(steps, failStep{Sets: sets, Reps: reps})
			}
		}
	}
	return steps
}

func roundToPrecision(val float64, precision float64) float64 {
	if precision <= 0 {
		return val
	}
	ratio := val / precision
	var rounded int
	if ratio >= 0 {
		rounded = int(ratio + 0.5)
	} else {
		rounded = int(ratio - 0.5)
	}
	return float64(rounded) * precision
}

func buildLinearProgressionState(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	session ApplySessionProgressionInput,
) UpsertProgressionStateInput {
	failSequenceStr := asString(block.Data["fail_sequence"])
	if failSequenceStr == "" {
		if prog, ok := block.Data["progression"].(map[string]any); ok {
			failSequenceStr = asString(prog["fail_sequence"])
		}
	}
	resetPercent := parseNumberValue(block.Data["reset_percent"])
	if resetPercent <= 0 {
		if prog, ok := block.Data["progression"].(map[string]any); ok {
			resetPercent = parseNumberValue(prog["reset_percent"])
		}
	}
	if resetPercent <= 0 {
		resetPercent = 0.85 // default to 85% GZCLP reset
	}
	precision := parseNumberValue(block.Data["rounding_precision"])
	deloadWeeks := intOrDefault(block.Data["deload_weeks"], 0)
	deloadPercent := parseNumberValue(block.Data["deload_percent"])
	if deloadPercent <= 0 {
		if prog, ok := block.Data["progression"].(map[string]any); ok {
			deloadPercent = parseNumberValue(prog["deload_percent"])
		}
	}
	if deloadPercent <= 0 {
		deloadPercent = 0.90 // default to 90% deload
	}

	currentSeqIndex := 0
	sessionCount := 0
	if hasExisting && existing.Metadata != nil {
		if val, ok := existing.Metadata["current_sequence_index"]; ok {
			currentSeqIndex = intOrDefault(val, 0)
		}
		if val, ok := existing.Metadata["session_count"]; ok {
			sessionCount = intOrDefault(val, 0)
		}
	}

	// Parse steps if sequence exists
	var steps []failStep
	if failSequenceStr != "" {
		steps = parseFailSequence(failSequenceStr)
	}

	if session.IsDeload && hasExisting {
		return UpsertProgressionStateInput{
			UserID:          session.UserID,
			WorkflowID:      session.WorkflowID,
			WorkflowBlockID: block.ID,
			BlockKey:        block.BlockKey,
			NodeTypeSlug:    block.NodeTypeSlug,
			StateType:       StateTypeLinear,
			ExerciseName:    asString(block.Data["exercise_name"]),
			Outcome:         OutcomeMaintain,
			CurrentLoad:     existing.CurrentLoad,
			SuggestedLoad:   existing.SuggestedLoad,
			AvgActualRPE:    existing.AvgActualRPE,
			AvgActualRIR:    existing.AvgActualRIR,
			LastSessionID:   session.SessionID,
			LastLogCount:    len(logs),
			Summary:         "Deload session completed. Preserving baseline load and sequence for the regular training cycle.",
			Metadata: map[string]any{
				"current_sequence_index": currentSeqIndex,
				"session_count":          sessionCount,
				"is_deload":              true,
				"baseline_load":          existing.SuggestedLoad,
			},
		}
	}

	var setsPlanned int
	var repsPrescribed string
	if len(steps) > 0 {
		// Ensure currentSeqIndex is within bounds
		if currentSeqIndex < 0 || currentSeqIndex >= len(steps) {
			currentSeqIndex = 0
		}
		setsPlanned = steps[currentSeqIndex].Sets
		repsPrescribed = steps[currentSeqIndex].Reps
	} else {
		setsPlanned = intOrDefault(block.Data["sets"], len(logs))
		repsPrescribed = asString(block.Data["reps"])
	}

	if repsPrescribed == "" && len(logs) > 0 {
		repsPrescribed = logs[0].PrescribedReps
	}
	lowerTarget, _ := parseRepRange(repsPrescribed)

	increment := parseNumberValue(block.Data["increment"])
	if increment == 0 {
		if prog, ok := block.Data["progression"].(map[string]any); ok {
			increment = parseNumberValue(prog["increment"])
		}
	}
	loadUnit := asString(block.Data["load_unit"])

	currentLoad := resolveLinearCurrentLoad(block, logs, existing, hasExisting, loadUnit)
	currentLoadValue, hasCurrentLoad := parseNumberString(currentLoad)
	avgRPE, avgRPELabel, hasRPE := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRPE })
	avgRIR, avgRIRLabel, hasRIR := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRIR })

	allSetsCompleted := len(logs) >= setsPlanned
	missedTarget := anyRepTargetMiss(logs, lowerTarget)

	outcome := OutcomeMaintain
	suggestedLoad := currentLoad
	suggestedSeqIndex := currentSeqIndex
	summary := "Keep the current load next session."

	switch {
	case missedTarget || !allSetsCompleted || isLinearTooHard(hasRPE, avgRPE, hasRIR, avgRIR):
		outcome = OutcomeReduce
		sessionCount = 0 // reset consecutive sessions on failure
		if len(steps) > 0 {
			if currentSeqIndex < len(steps)-1 {
				suggestedSeqIndex = currentSeqIndex + 1
				suggestedLoad = currentLoad // Keep the same load when changing schemes in GZCLP
				nextStep := steps[suggestedSeqIndex]
				summary = fmt.Sprintf("Failed rep target. Transition to next scheme: %dx%s at %s.", nextStep.Sets, nextStep.Reps, currentLoad)
			} else {
				suggestedSeqIndex = 0
				if hasCurrentLoad {
					rawReset := currentLoadValue * resetPercent
					if precision > 0 {
						rawReset = roundToPrecision(rawReset, precision)
					}
					suggestedLoad = formatLoad(maxFloat(rawReset, 0), loadUnit)
				}
				nextStep := steps[0]
				summary = fmt.Sprintf("Failed final rep scheme. Resetting sequence to %dx%s and reducing load by %d%% to %s.", nextStep.Sets, nextStep.Reps, int((1.0-resetPercent)*100), suggestedLoad)
			}
		} else {
			if hasCurrentLoad && increment > 0 {
				rawReduce := currentLoadValue - increment
				if precision > 0 {
					rawReduce = roundToPrecision(rawReduce, precision)
				}
				suggestedLoad = formatLoad(maxFloat(rawReduce, 0), loadUnit)
			}
			summary = "Reduce the load next session. Reps fell off or effort ran too high."
		}

	case isLinearEasy(hasRPE, avgRPE, hasRIR, avgRIR):
		outcome = OutcomeIncrease
		sessionCount++

		if deloadWeeks > 0 && sessionCount%deloadWeeks == 0 {
			if hasCurrentLoad {
				rawDeload := currentLoadValue * deloadPercent
				if precision > 0 {
					rawDeload = roundToPrecision(rawDeload, precision)
				}
				suggestedLoad = formatLoad(maxFloat(rawDeload, 0), loadUnit)
			}
			summary = fmt.Sprintf("Deload milestone reached (%d sessions). Reducing load by %d%% to %s next session for recovery.", sessionCount, int((1.0-deloadPercent)*100), suggestedLoad)
		} else {
			if hasCurrentLoad && increment > 0 {
				rawIncrease := currentLoadValue + increment
				if precision > 0 {
					rawIncrease = roundToPrecision(rawIncrease, precision)
				}
				suggestedLoad = formatLoad(rawIncrease, loadUnit)
			}
			summary = "Add load next session. The work stayed within a manageable effort."
		}

	default:
		summary = "Keep the load steady next session. The work landed close to the target effort."
	}

	return UpsertProgressionStateInput{
		UserID:          session.UserID,
		WorkflowID:      session.WorkflowID,
		WorkflowBlockID: block.ID,
		BlockKey:        block.BlockKey,
		NodeTypeSlug:    block.NodeTypeSlug,
		StateType:       StateTypeLinear,
		ExerciseName:    asString(block.Data["exercise_name"]),
		Outcome:         outcome,
		CurrentLoad:     currentLoad,
		SuggestedLoad:   suggestedLoad,
		AvgActualRPE:    avgRPELabel,
		AvgActualRIR:    avgRIRLabel,
		LastSessionID:   session.SessionID,
		LastLogCount:    len(logs),
		Summary:         summary,
		Metadata: map[string]any{
			"increment":              increment,
			"load_unit":              loadUnit,
			"progression_rule":       asString(block.Data["progression_rule"]),
			"sets_planned":           setsPlanned,
			"reps_planned":           repsPrescribed,
			"target_reps_lower":      lowerTarget,
			"current_sequence_index": suggestedSeqIndex,
			"fail_sequence":          failSequenceStr,
			"session_count":          sessionCount,
		},
	}
}

func buildWaveProgressionState(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	session ApplySessionProgressionInput,
) UpsertProgressionStateInput {
	if session.IsDeload && hasExisting {
		return UpsertProgressionStateInput{
			UserID:                   session.UserID,
			WorkflowID:               session.WorkflowID,
			WorkflowBlockID:          block.ID,
			BlockKey:                 block.BlockKey,
			NodeTypeSlug:             block.NodeTypeSlug,
			StateType:                StateTypeWave,
			ExerciseName:             asString(block.Data["exercise_name"]),
			Outcome:                  OutcomeMaintain,
			CurrentWeek:              existing.CurrentWeek,
			SuggestedWeek:            existing.SuggestedWeek,
			SuggestedIntensityOffset: existing.SuggestedIntensityOffset,
			AvgActualRPE:             existing.AvgActualRPE,
			AvgActualRIR:             existing.AvgActualRIR,
			LastSessionID:            session.SessionID,
			LastLogCount:             len(logs),
			Summary:                  fmt.Sprintf("Deload session completed: week %d baseline preserved.", existing.CurrentWeek),
			Metadata: map[string]any{
				"is_deload": true,
			},
		}
	}

	currentWeek := resolveWaveCurrentWeek(block, logs, existing, hasExisting)
	currentOffset := 0.0
	if hasExisting {
		if existing.SuggestedWeek > 0 {
			currentWeek = existing.SuggestedWeek
		}
		if offset, ok := parseNumberString(existing.SuggestedIntensityOffset); ok {
			currentOffset = offset
		}
	}

	maxWeek := countConfiguredWaveWeeks(block.Data)
	topLog := logs[len(logs)-1]
	targetRPE, hasTargetRPE := parseNumberString(topLog.PrescribedRPE)
	avgRPE, avgRPELabel, hasAvgRPE := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRPE })
	actualRIR, avgRIRLabel, hasRIR := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRIR })
	observedRPE := avgRPE
	hasObservedRPE := hasAvgRPE
	if topActualRPE, ok := parseNumberString(topLog.ActualRPE); ok {
		observedRPE = topActualRPE
		hasObservedRPE = true
	}
	missedTarget := anyRepTargetMiss(logs, 0)

	suggestedWeek := currentWeek
	suggestedOffset := currentOffset
	outcome := OutcomeMaintain
	summary := fmt.Sprintf("Repeat week %d and confirm the same loading.", currentWeek)

	switch {
	case missedTarget || isWaveTooHard(hasTargetRPE, targetRPE, hasObservedRPE, observedRPE, hasRIR, actualRIR):
		outcome = OutcomeReduce
		suggestedOffset = currentOffset - 2.5
		summary = fmt.Sprintf("Repeat week %d with %.1f%% less intensity. The top set overshot the target effort.", currentWeek, 2.5)
	case isWaveEasy(hasTargetRPE, targetRPE, hasObservedRPE, observedRPE, hasRIR, actualRIR):
		outcome = OutcomeIncrease
		if currentWeek < maxWeek {
			suggestedWeek = currentWeek + 1
			suggestedOffset = 0
			summary = fmt.Sprintf("Advance to week %d next session. The wave moved cleanly at the target effort.", suggestedWeek)
		} else {
			suggestedOffset = currentOffset + 2.5
			summary = fmt.Sprintf("Stay on week %d and add %.1f%% to the wave next session.", currentWeek, 2.5)
		}
	default:
		summary = fmt.Sprintf("Repeat week %d at the current wave prescription.", currentWeek)
	}

	return UpsertProgressionStateInput{
		UserID:                   session.UserID,
		WorkflowID:               session.WorkflowID,
		WorkflowBlockID:          block.ID,
		BlockKey:                 block.BlockKey,
		NodeTypeSlug:             block.NodeTypeSlug,
		StateType:                StateTypeWave,
		ExerciseName:             asString(block.Data["exercise_name"]),
		Outcome:                  outcome,
		CurrentWeek:              currentWeek,
		SuggestedWeek:            suggestedWeek,
		SuggestedIntensityOffset: formatSignedNumber(currentOffsetToStore(suggestedOffset)),
		AvgActualRPE:             avgRPELabel,
		AvgActualRIR:             avgRIRLabel,
		LastSessionID:            session.SessionID,
		LastLogCount:             len(logs),
		Summary:                  summary,
		Metadata: map[string]any{
			"max_week":           maxWeek,
			"current_offset":     formatSignedNumber(currentOffset),
			"top_set_target_rpe": topLog.PrescribedRPE,
		},
	}
}

func buildSkillProgressionState(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	session ApplySessionProgressionInput,
) UpsertProgressionStateInput {
	targetReps := asString(block.Data["reps"])
	if targetReps == "" && len(logs) > 0 {
		targetReps = logs[0].PrescribedReps
	}
	lowerTarget, upperTarget := parseRepRange(targetReps)
	avgReps, _, hasReps := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualReps })
	avgRPE, avgRPELabel, hasRPE := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRPE })
	avgRIR, avgRIRLabel, hasRIR := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRIR })

	outcome := OutcomeMaintain
	summary := "Keep the same variation next session."
	action := "maintain"

	switch {
	case isSkillHighQuality(block, hasReps, avgReps, upperTarget, hasRPE, avgRPE, hasRIR, avgRIR):
		outcome = OutcomeAdvance
		action = "advance"
		summary = "Advance the variation next session. Quality stayed high with room in reserve."
	case isSkillTooHard(hasReps, avgReps, lowerTarget, hasRPE, avgRPE, hasRIR, avgRIR):
		outcome = OutcomeRegress
		action = "regress"
		summary = "Use an easier variation next session. Quality or reps fell off too early."
	default:
		summary = "Keep the same variation next session and own the reps cleanly."
	}

	currentLoad := ""
	if hasExisting {
		currentLoad = existing.CurrentLoad
	}

	return UpsertProgressionStateInput{
		UserID:          session.UserID,
		WorkflowID:      session.WorkflowID,
		WorkflowBlockID: block.ID,
		BlockKey:        block.BlockKey,
		NodeTypeSlug:    block.NodeTypeSlug,
		StateType:       StateTypeSkill,
		ExerciseName:    asString(block.Data["exercise_name"]),
		Outcome:         outcome,
		CurrentLoad:     currentLoad,
		AvgActualRPE:    avgRPELabel,
		AvgActualRIR:    avgRIRLabel,
		LastSessionID:   session.SessionID,
		LastLogCount:    len(logs),
		Summary:         summary,
		Metadata: map[string]any{
			"suggested_action": action,
			"target_reps":      targetReps,
			"notes":            asString(block.Data["notes"]),
		},
	}
}

func groupHistoricalLogsByBlock(entries []HistoricalCompletedSetLog) map[int]historicalBlockLogs {
	grouped := make(map[int]historicalBlockLogs, len(entries))
	for _, entry := range entries {
		if entry.WorkflowBlockID == nil {
			continue
		}
		blockID := *entry.WorkflowBlockID
		group := grouped[blockID]
		if group.SessionID == 0 {
			group.SessionID = entry.SessionID
		}
		group.Logs = append(group.Logs, entry.CompletedSetLog)
		grouped[blockID] = group
	}

	for blockID, group := range grouped {
		slices.SortFunc(group.Logs, func(a, b CompletedSetLog) int {
			return a.SetIndex - b.SetIndex
		})
		grouped[blockID] = group
	}

	return grouped
}

func progressionStateFromUpsert(in UpsertProgressionStateInput) ProgressionState {
	return ProgressionState{
		UserID:                   in.UserID,
		WorkflowID:               in.WorkflowID,
		WorkflowBlockID:          in.WorkflowBlockID,
		BlockKey:                 in.BlockKey,
		NodeTypeSlug:             in.NodeTypeSlug,
		StateType:                in.StateType,
		ExerciseName:             in.ExerciseName,
		Outcome:                  in.Outcome,
		CurrentLoad:              in.CurrentLoad,
		SuggestedLoad:            in.SuggestedLoad,
		CurrentWeek:              in.CurrentWeek,
		SuggestedWeek:            in.SuggestedWeek,
		SuggestedIntensityOffset: in.SuggestedIntensityOffset,
		AvgActualRPE:             in.AvgActualRPE,
		AvgActualRIR:             in.AvgActualRIR,
		LastSessionID:            in.LastSessionID,
		LastLogCount:             in.LastLogCount,
		Summary:                  in.Summary,
		Metadata:                 in.Metadata,
	}
}

func splitPair(val string) (string, string) {
	val = strings.TrimSpace(val)
	if val == "" {
		return "", ""
	}
	parts := strings.Split(val, "/")
	if len(parts) >= 2 {
		return strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1])
	}
	return val, ""
}

func parseRepsMinMax(reps string) (int, int) {
	matches := digitPattern.FindAllString(reps, -1)
	if len(matches) == 0 {
		return 5, 8
	}
	first, _ := strconv.Atoi(matches[0])
	if len(matches) == 1 {
		return first, first
	}
	last, _ := strconv.Atoi(matches[len(matches)-1])
	if last < first {
		last = first
	}
	return first, last
}

func parseFirstInt(val string) (int, bool) {
	match := digitPattern.FindString(val)
	if match == "" {
		return 0, false
	}
	num, err := strconv.Atoi(match)
	if err != nil {
		return 0, false
	}
	return num, true
}

func parseMinMaxConfig(minVal, maxVal any, fallbackReps string) (int, int) {
	minR := intOrDefault(minVal, 0)
	maxR := intOrDefault(maxVal, 0)
	if minR > 0 && maxR > 0 {
		if maxR < minR {
			maxR = minR
		}
		return minR, maxR
	}
	return parseRepsMinMax(fallbackReps)
}

type singleProgressionResult struct {
	CurrentLoad   string
	SuggestedLoad string
	TargetReps    string
	Outcome       string
	Summary       string
	Metadata      map[string]any
}

func evalSingleExerciseProgression(
	exerciseName string,
	progType string,
	setsPlanned int,
	repsStr string,
	minReps int,
	maxReps int,
	increment float64,
	loadUnit string,
	configuredLoad float64,
	existingSuggestedLoad string,
	existingMetadata map[string]any,
	logs []CompletedSetLog,
	isDeload bool,
) singleProgressionResult {
	if loadUnit == "" {
		loadUnit = "kg"
	}
	if setsPlanned <= 0 {
		setsPlanned = 3
	}
	if minReps <= 0 || maxReps <= 0 {
		minReps, maxReps = parseRepsMinMax(repsStr)
	}
	if increment <= 0 {
		increment = 2.5
	}

	currentLoad := ""
	for _, l := range logs {
		if val := strings.TrimSpace(l.ActualLoad); val != "" && val != "0" && val != "0 kg" && val != "0.0" && val != "0.0 kg" {
			if num, ok := parseNumberString(val); ok {
				currentLoad = formatLoad(num, loadUnit)
				break
			}
			currentLoad = val
			break
		}
	}
	if currentLoad == "" && existingSuggestedLoad != "" && existingSuggestedLoad != "0" && existingSuggestedLoad != "0 kg" && existingSuggestedLoad != "0.0" && existingSuggestedLoad != "0.0 kg" {
		currentLoad = existingSuggestedLoad
	}
	if currentLoad == "" && configuredLoad > 0 {
		currentLoad = formatLoad(configuredLoad, loadUnit)
	}
	if currentLoad == "" {
		for _, l := range logs {
			if val := strings.TrimSpace(l.ActualLoad); val != "" {
				currentLoad = val
				break
			}
		}
	}
	if currentLoad == "" && existingSuggestedLoad != "" {
		currentLoad = existingSuggestedLoad
	}
	if currentLoad == "" {
		currentLoad = formatLoad(0, loadUnit)
	}
	currentLoadVal, hasCurrentLoad := parseNumberString(currentLoad)
	if hasCurrentLoad {
		currentLoad = formatLoad(currentLoadVal, loadUnit)
	}

	actualReps := make([]int, 0, len(logs))
	for _, l := range logs {
		if !l.Completed {
			continue
		}
		if r, ok := parseFirstInt(l.ActualReps); ok && r > 0 {
			actualReps = append(actualReps, r)
		}
	}

	minActualReps := 0
	if len(actualReps) > 0 {
		minActualReps = actualReps[0]
		for _, r := range actualReps {
			if r < minActualReps {
				minActualReps = r
			}
		}
	}

	allSetsCompleted := len(actualReps) >= setsPlanned

	currentRepTarget := minReps
	if existingMetadata != nil {
		if tr := intOrDefault(existingMetadata["target_reps"], 0); tr > 0 {
			currentRepTarget = tr
		}
	}
	if currentRepTarget < minReps {
		currentRepTarget = minReps
	}
	if currentRepTarget > maxReps {
		currentRepTarget = maxReps
	}

	if isDeload && existingSuggestedLoad != "" {
		return singleProgressionResult{
			CurrentLoad:   currentLoad,
			SuggestedLoad: existingSuggestedLoad,
			TargetReps:    strconv.Itoa(currentRepTarget),
			Outcome:       OutcomeMaintain,
			Summary:       fmt.Sprintf("Deload session completed. Preserved %s at %d reps.", existingSuggestedLoad, currentRepTarget),
			Metadata: map[string]any{
				"target_reps":   currentRepTarget,
				"min_reps":      minReps,
				"max_reps":      maxReps,
				"is_deload":     true,
				"baseline_load": existingSuggestedLoad,
			},
		}
	}

	switch progType {
	case "double":
		if allSetsCompleted && minActualReps >= maxReps {
			outcome := OutcomeIncrease
			suggestedLoad := currentLoad
			if hasCurrentLoad && increment > 0 {
				suggestedLoad = formatLoad(currentLoadVal+increment, loadUnit)
			}
			return singleProgressionResult{
				CurrentLoad:   currentLoad,
				SuggestedLoad: suggestedLoad,
				TargetReps:    strconv.Itoa(minReps),
				Outcome:       outcome,
				Summary:       fmt.Sprintf("Hit %d reps across all %d sets! Adding load to %s and resetting target to %d reps.", maxReps, setsPlanned, suggestedLoad, minReps),
				Metadata: map[string]any{
					"target_reps":      minReps,
					"min_reps":         minReps,
					"max_reps":         maxReps,
					"increment":        increment,
					"load_unit":        loadUnit,
					"progression_type": "double",
				},
			}
		}

		if allSetsCompleted && minActualReps >= currentRepTarget {
			nextTarget := minActualReps + 1
			if nextTarget > maxReps {
				nextTarget = maxReps
			}
			return singleProgressionResult{
				CurrentLoad:   currentLoad,
				SuggestedLoad: currentLoad,
				TargetReps:    strconv.Itoa(nextTarget),
				Outcome:       OutcomeMaintain,
				Summary:       fmt.Sprintf("Completed %d reps across all sets. Maintained %s; target %d reps next session.", minActualReps, currentLoad, nextTarget),
				Metadata: map[string]any{
					"target_reps":      nextTarget,
					"min_reps":         minReps,
					"max_reps":         maxReps,
					"increment":        increment,
					"load_unit":        loadUnit,
					"progression_type": "double",
				},
			}
		}

		return singleProgressionResult{
			CurrentLoad:   currentLoad,
			SuggestedLoad: currentLoad,
			TargetReps:    strconv.Itoa(currentRepTarget),
			Outcome:       OutcomeMaintain,
			Summary:       fmt.Sprintf("Stay at %s. Aim for %d reps across all %d sets.", currentLoad, currentRepTarget, setsPlanned),
			Metadata: map[string]any{
				"target_reps":      currentRepTarget,
				"min_reps":         minReps,
				"max_reps":         maxReps,
				"increment":        increment,
				"load_unit":        loadUnit,
				"progression_type": "double",
			},
		}

	case "linear":
		lowerTarget := float64(minReps)
		if allSetsCompleted && float64(minActualReps) >= lowerTarget {
			suggestedLoad := currentLoad
			if hasCurrentLoad && increment > 0 {
				suggestedLoad = formatLoad(currentLoadVal+increment, loadUnit)
			}
			return singleProgressionResult{
				CurrentLoad:   currentLoad,
				SuggestedLoad: suggestedLoad,
				TargetReps:    repsStr,
				Outcome:       OutcomeIncrease,
				Summary:       fmt.Sprintf("Target completed. Adding %s next session (%s).", formatMetric(increment)+loadUnit, suggestedLoad),
				Metadata: map[string]any{
					"target_reps":      repsStr,
					"increment":        increment,
					"load_unit":        loadUnit,
					"progression_type": "linear",
				},
			}
		}
		return singleProgressionResult{
			CurrentLoad:   currentLoad,
			SuggestedLoad: currentLoad,
			TargetReps:    repsStr,
			Outcome:       OutcomeMaintain,
			Summary:       fmt.Sprintf("Maintain %s next session.", currentLoad),
			Metadata: map[string]any{
				"target_reps":      repsStr,
				"increment":        increment,
				"load_unit":        loadUnit,
				"progression_type": "linear",
			},
		}

	default: // "none"
		return singleProgressionResult{
			CurrentLoad:   currentLoad,
			SuggestedLoad: currentLoad,
			TargetReps:    repsStr,
			Outcome:       OutcomeMaintain,
			Summary:       fmt.Sprintf("Fixed prescription at %s.", currentLoad),
			Metadata: map[string]any{
				"target_reps":      repsStr,
				"load_unit":        loadUnit,
				"progression_type": "none",
			},
		}
	}
}

func buildDoubleProgressionState(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	session ApplySessionProgressionInput,
) UpsertProgressionStateInput {
	exerciseName := asString(block.Data["exercise_name"])
	setsPlanned := intOrDefault(block.Data["sets"], len(logs))
	repsStr := asString(block.Data["reps"])

	prog, _ := block.Data["progression"].(map[string]any)
	minReps := 5
	maxReps := 8
	increment := 2.5
	if prog != nil {
		minReps = intOrDefault(prog["min_reps"], 5)
		maxReps = intOrDefault(prog["max_reps"], 8)
		increment = parseNumberValue(prog["increment"])
		if increment == 0 {
			increment = 2.5
		}
	} else {
		minReps, maxReps = parseRepsMinMax(repsStr)
	}

	loadUnit := asString(block.Data["load_unit"])
	if loadUnit == "" {
		loadUnit = "kg"
	}
	configuredLoad := parseNumberValue(block.Data["load_value"])
	if configuredLoad == 0 {
		configuredLoad = parseNumberValue(block.Data["start_load"])
	}

	var existingLoad string
	var existingMeta map[string]any
	if hasExisting {
		existingLoad = existing.SuggestedLoad
		existingMeta = existing.Metadata
	}

	res := evalSingleExerciseProgression(
		exerciseName, "double", setsPlanned, repsStr, minReps, maxReps, increment, loadUnit,
		configuredLoad, existingLoad, existingMeta, logs, session.IsDeload,
	)

	_, avgRPELabel, _ := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRPE })
	_, avgRIRLabel, _ := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRIR })

	meta := res.Metadata
	if meta == nil {
		meta = map[string]any{}
	}
	meta["sets_planned"] = setsPlanned

	return UpsertProgressionStateInput{
		UserID:          session.UserID,
		WorkflowID:      session.WorkflowID,
		WorkflowBlockID: block.ID,
		BlockKey:        block.BlockKey,
		NodeTypeSlug:    block.NodeTypeSlug,
		StateType:       StateTypeDouble,
		ExerciseName:    exerciseName,
		Outcome:         res.Outcome,
		CurrentLoad:     res.CurrentLoad,
		SuggestedLoad:   res.SuggestedLoad,
		AvgActualRPE:    avgRPELabel,
		AvgActualRIR:    avgRIRLabel,
		LastSessionID:   session.SessionID,
		LastLogCount:    len(logs),
		Summary:         res.Summary,
		Metadata:        meta,
	}
}

func buildSupersetProgressionState(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	session ApplySessionProgressionInput,
) UpsertProgressionStateInput {
	exA := asString(block.Data["exercise_a_name"])
	if exA == "" {
		exA = "Exercise A"
	}
	exB := asString(block.Data["exercise_b_name"])
	if exB == "" {
		exB = "Exercise B"
	}

	setsPlanned := intOrDefault(block.Data["sets"], len(logs))
	if setsPlanned <= 0 {
		setsPlanned = 3
	}

	repsAStr := asString(block.Data["reps_a"])
	if repsAStr == "" {
		repsAStr = "5-8"
	}
	repsBStr := asString(block.Data["reps_b"])
	if repsBStr == "" {
		repsBStr = "5-8"
	}

	minA, maxA := parseMinMaxConfig(block.Data["min_reps_a"], block.Data["max_reps_a"], repsAStr)
	minB, maxB := parseMinMaxConfig(block.Data["min_reps_b"], block.Data["max_reps_b"], repsBStr)

	progTypeA := asString(block.Data["progression_type_a"])
	if progTypeA == "" {
		progTypeA = "none"
	}
	progTypeB := asString(block.Data["progression_type_b"])
	if progTypeB == "" {
		progTypeB = "none"
	}

	incA := parseNumberValue(block.Data["increment_a"])
	if incA == 0 {
		incA = 2.5
	}
	incB := parseNumberValue(block.Data["increment_b"])
	if incB == 0 {
		incB = 2.5
	}

	unitA := asString(block.Data["load_unit_a"])
	if unitA == "" {
		unitA = "kg"
	}
	unitB := asString(block.Data["load_unit_b"])
	if unitB == "" {
		unitB = "kg"
	}

	startLoadA := parseNumberValue(block.Data["start_load_a"])
	if startLoadA == 0 {
		startLoadA = parseNumberValue(block.Data["load_value_a"])
	}
	startLoadB := parseNumberValue(block.Data["start_load_b"])
	if startLoadB == 0 {
		startLoadB = parseNumberValue(block.Data["load_value_b"])
	}

	logsA := make([]CompletedSetLog, len(logs))
	logsB := make([]CompletedSetLog, len(logs))
	for i, l := range logs {
		rA, rB := splitPair(l.ActualReps)
		ldA, ldB := splitPair(l.ActualLoad)
		logsA[i] = CompletedSetLog{
			WorkflowBlockID: l.WorkflowBlockID,
			BlockClientID:   l.BlockClientID,
			NodeTypeSlug:    l.NodeTypeSlug,
			SetIndex:        l.SetIndex,
			PrescribedReps:  rA,
			PrescribedLoad:  ldA,
			ActualReps:      rA,
			ActualLoad:      ldA,
			ActualRPE:       l.ActualRPE,
			ActualRIR:       l.ActualRIR,
			Completed:       l.Completed,
			Notes:           l.Notes,
		}
		logsB[i] = CompletedSetLog{
			WorkflowBlockID: l.WorkflowBlockID,
			BlockClientID:   l.BlockClientID,
			NodeTypeSlug:    l.NodeTypeSlug,
			SetIndex:        l.SetIndex,
			PrescribedReps:  rB,
			PrescribedLoad:  ldB,
			ActualReps:      rB,
			ActualLoad:      ldB,
			ActualRPE:       l.ActualRPE,
			ActualRIR:       l.ActualRIR,
			Completed:       l.Completed,
			Notes:           l.Notes,
		}
	}

	var existingMetaA, existingMetaB map[string]any
	var existingLoadA, existingLoadB string
	if hasExisting && existing.Metadata != nil {
		if aMap, ok := existing.Metadata["exercise_a"].(map[string]any); ok {
			existingMetaA = aMap
			existingLoadA = asString(aMap["suggested_load"])
		}
		if bMap, ok := existing.Metadata["exercise_b"].(map[string]any); ok {
			existingMetaB = bMap
			existingLoadB = asString(bMap["suggested_load"])
		}
		if existingLoadA == "" {
			existingLoadA = asString(existing.Metadata["suggested_load_a"])
		}
		if existingLoadB == "" {
			existingLoadB = asString(existing.Metadata["suggested_load_b"])
		}
	}

	resA := evalSingleExerciseProgression(
		exA, progTypeA, setsPlanned, repsAStr, minA, maxA, incA, unitA,
		startLoadA, existingLoadA, existingMetaA, logsA, session.IsDeload,
	)
	resB := evalSingleExerciseProgression(
		exB, progTypeB, setsPlanned, repsBStr, minB, maxB, incB, unitB,
		startLoadB, existingLoadB, existingMetaB, logsB, session.IsDeload,
	)

	overallOutcome := OutcomeMaintain
	if resA.Outcome == OutcomeIncrease || resB.Outcome == OutcomeIncrease {
		overallOutcome = OutcomeIncrease
	} else if resA.Outcome == OutcomeReduce || resB.Outcome == OutcomeReduce {
		overallOutcome = OutcomeReduce
	}

	_, avgRPELabel, _ := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRPE })
	_, avgRIRLabel, _ := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRIR })

	summary := fmt.Sprintf("%s: %s | %s: %s", exA, resA.Summary, exB, resB.Summary)

	return UpsertProgressionStateInput{
		UserID:          session.UserID,
		WorkflowID:      session.WorkflowID,
		WorkflowBlockID: block.ID,
		BlockKey:        block.BlockKey,
		NodeTypeSlug:    block.NodeTypeSlug,
		StateType:       StateTypeSuperset,
		ExerciseName:    exA + " + " + exB,
		Outcome:         overallOutcome,
		CurrentLoad:     resA.CurrentLoad + " / " + resB.CurrentLoad,
		SuggestedLoad:   resA.SuggestedLoad + " / " + resB.SuggestedLoad,
		AvgActualRPE:    avgRPELabel,
		AvgActualRIR:    avgRIRLabel,
		LastSessionID:   session.SessionID,
		LastLogCount:    len(logs),
		Summary:         summary,
		Metadata: map[string]any{
			"exercise_a":       resA.Metadata,
			"exercise_b":       resB.Metadata,
			"suggested_load_a": resA.SuggestedLoad,
			"suggested_load_b": resB.SuggestedLoad,
			"suggested_reps_a": resA.TargetReps,
			"suggested_reps_b": resB.TargetReps,
			"sets_planned":     setsPlanned,
		},
	}
}

func (s *Service) syncProgressionStateWithBlock(state *ProgressionState, block resolvedWorkflowBlock) {
	if state.NodeTypeSlug != "linear_progression" && state.NodeTypeSlug != "exercise" && state.NodeTypeSlug != "superset" {
		return
	}
	if state.Metadata == nil {
		state.Metadata = make(map[string]any)
	}

	if state.NodeTypeSlug == "superset" {
		sets := intOrDefault(block.Data["sets"], 3)
		state.Metadata["sets_planned"] = sets
		return
	}
	if state.Metadata == nil {
		state.Metadata = make(map[string]any)
	}

	blockFailSeq := asString(block.Data["fail_sequence"])
	if blockFailSeq == "" {
		if prog, ok := block.Data["progression"].(map[string]any); ok {
			blockFailSeq = asString(prog["fail_sequence"])
		}
	}
	stateFailSeq := asString(state.Metadata["fail_sequence"])

	if blockFailSeq != stateFailSeq {
		state.Metadata["fail_sequence"] = blockFailSeq
		if blockFailSeq != "" {
			steps := parseFailSequence(blockFailSeq)
			if len(steps) > 0 {
				state.Metadata["current_sequence_index"] = 0
				state.Metadata["sets_planned"] = steps[0].Sets
				state.Metadata["reps_planned"] = steps[0].Reps
				lower, _ := parseRepRange(steps[0].Reps)
				state.Metadata["target_reps_lower"] = lower
			}
		} else {
			state.Metadata["current_sequence_index"] = 0
			sets := intOrDefault(block.Data["sets"], 3)
			reps := asString(block.Data["reps"])
			state.Metadata["sets_planned"] = sets
			state.Metadata["reps_planned"] = reps
			lower, _ := parseRepRange(reps)
			state.Metadata["target_reps_lower"] = lower
		}
	} else if blockFailSeq == "" {
		blockSets := intOrDefault(block.Data["sets"], 3)
		blockReps := asString(block.Data["reps"])

		stateSets := intOrDefault(state.Metadata["sets_planned"], 3)
		stateReps := asString(state.Metadata["reps_planned"])

		if blockSets != stateSets || blockReps != stateReps {
			state.Metadata["sets_planned"] = blockSets
			state.Metadata["reps_planned"] = blockReps
			lower, _ := parseRepRange(blockReps)
			state.Metadata["target_reps_lower"] = lower
		}
	} else {
		steps := parseFailSequence(blockFailSeq)
		if len(steps) > 0 {
			currIdx := intOrDefault(state.Metadata["current_sequence_index"], 0)
			if currIdx < 0 || currIdx >= len(steps) {
				currIdx = 0
				state.Metadata["current_sequence_index"] = 0
			}
			expectedSets := steps[currIdx].Sets
			expectedReps := steps[currIdx].Reps
			actualSets := intOrDefault(state.Metadata["sets_planned"], 0)
			actualReps := asString(state.Metadata["reps_planned"])
			if actualSets != expectedSets || actualReps != expectedReps {
				state.Metadata["sets_planned"] = expectedSets
				state.Metadata["reps_planned"] = expectedReps
				lower, _ := parseRepRange(expectedReps)
				state.Metadata["target_reps_lower"] = lower
			}
		}
	}

	state.Metadata["increment"] = parseNumberValue(block.Data["increment"])
	state.Metadata["load_unit"] = asString(block.Data["load_unit"])
	state.Metadata["progression_rule"] = asString(block.Data["progression_rule"])
}

func enrichStateMetadata(
	block resolvedWorkflowBlock,
	metadata map[string]any,
	history []waveHistorySession,
) map[string]any {
	if metadata == nil {
		metadata = map[string]any{}
	}
	if block.NodeTypeSlug != "wave" || len(history) == 0 {
		return metadata
	}

	enriched := make(map[string]any, len(metadata)+1)
	for key, value := range metadata {
		enriched[key] = value
	}
	enriched["week_history"] = buildWaveWeekHistoryMetadata(block.Data, history)
	return enriched
}

func okState(states map[string]ProgressionState, key string) bool {
	_, ok := states[key]
	return ok
}

func looksLikeSkillProgression(block resolvedWorkflowBlock) bool {
	name := strings.ToLower(asString(block.Data["exercise_name"]))
	notes := strings.ToLower(asString(block.Data["notes"]))
	keywords := []string{
		"progression", "variation", "skill", "practice", "crow", "lever",
		"handstand", "pistol", "pose",
	}
	for _, keyword := range keywords {
		if strings.Contains(name, keyword) || strings.Contains(notes, keyword) {
			return true
		}
	}
	return false
}

func shouldCreateSkillStateWithoutLogs(block resolvedWorkflowBlock) bool {
	if block.NodeTypeSlug != "exercise" && block.NodeTypeSlug != "exercise_timed" {
		return false
	}
	return looksLikeSkillProgression(block)
}

func blockDisplayName(block workflowBlockConfig) string {
	if value := asString(block.Data["exercise_name"]); value != "" {
		return value
	}
	if value := asString(block.Data["title"]); value != "" {
		return value
	}
	if exA := asString(block.Data["exercise_a_name"]); exA != "" {
		if exB := asString(block.Data["exercise_b_name"]); exB != "" {
			return exA + " + " + exB
		}
		return exA
	}
	return block.NodeTypeSlug
}

func sanitizeKey(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, " ", "-")
	value = strings.ReplaceAll(value, "/", "-")
	return value
}

func asString(value any) string {
	if raw, ok := value.(string); ok {
		return strings.TrimSpace(raw)
	}
	return ""
}

func intOrDefault(value any, fallback int) int {
	switch typed := value.(type) {
	case int:
		return typed
	case int32:
		return int(typed)
	case int64:
		return int(typed)
	case float64:
		return int(typed)
	default:
		return fallback
	}
}

func parseNumberValue(value any) float64 {
	switch typed := value.(type) {
	case int:
		return float64(typed)
	case int32:
		return float64(typed)
	case int64:
		return float64(typed)
	case float64:
		return typed
	case string:
		number, _ := parseNumberString(typed)
		return number
	default:
		return 0
	}
}

func parseNumberString(value string) (float64, bool) {
	match := numberPattern.FindString(strings.TrimSpace(value))
	if match == "" {
		return 0, false
	}
	number, err := strconv.ParseFloat(match, 64)
	if err != nil {
		return 0, false
	}
	return number, true
}

func parseRepRange(value string) (float64, float64) {
	matches := numberPattern.FindAllString(value, -1)
	if len(matches) == 0 {
		return 0, 0
	}
	if len(matches) == 1 {
		number, _ := strconv.ParseFloat(matches[0], 64)
		return number, number
	}
	first, _ := strconv.ParseFloat(matches[0], 64)
	last, _ := strconv.ParseFloat(matches[len(matches)-1], 64)
	return first, last
}

func averageMetric(logs []CompletedSetLog, extractor func(CompletedSetLog) string) (float64, string, bool) {
	total := 0.0
	count := 0.0
	for _, log := range logs {
		value, ok := parseNumberString(extractor(log))
		if !ok {
			continue
		}
		total += value
		count += 1
	}
	if count == 0 {
		return 0, "", false
	}
	average := total / count
	return average, formatMetric(average), true
}

func formatMetric(value float64) string {
	if value == float64(int64(value)) {
		return strconv.FormatInt(int64(value), 10)
	}
	return strconv.FormatFloat(value, 'f', 1, 64)
}

func formatLoad(value float64, unit string) string {
	label := formatMetric(value)
	if strings.TrimSpace(unit) == "" {
		return label
	}
	return label + " " + strings.TrimSpace(unit)
}

func resolveLinearCurrentLoad(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	loadUnit string,
) string {
	// 1. Check if the user logged an actual load for sets in the current session
	for _, log := range logs {
		if val := strings.TrimSpace(log.ActualLoad); val != "" && val != "0" && val != "0 kg" && val != "0.0" && val != "0.0 kg" {
			if num, ok := parseNumberString(val); ok {
				return formatLoad(num, loadUnit)
			}
			return val
		}
	}
	// 2. Check if the current session sets have a non-zero prescribed load
	for _, log := range logs {
		if val := strings.TrimSpace(log.PrescribedLoad); val != "" && val != "0" && val != "0 kg" && val != "0.0" && val != "0.0 kg" {
			if num, ok := parseNumberString(val); ok {
				return formatLoad(num, loadUnit)
			}
			return val
		}
	}
	// 3. Check existing progression state if it has a non-zero suggested load
	if hasExisting && strings.TrimSpace(existing.SuggestedLoad) != "" && existing.SuggestedLoad != "0" && existing.SuggestedLoad != "0 kg" && existing.SuggestedLoad != "0.0" && existing.SuggestedLoad != "0.0 kg" {
		return existing.SuggestedLoad
	}
	// 3. Check if block has a configured start_load or load_value > 0
	if configured := parseNumberValue(block.Data["start_load"]); configured > 0 {
		return formatLoad(configured, loadUnit)
	}
	if configured := parseNumberValue(block.Data["load_value"]); configured > 0 {
		return formatLoad(configured, loadUnit)
	}
	// 4. Fallback to any non-empty log actual load
	for _, log := range logs {
		if val := strings.TrimSpace(log.ActualLoad); val != "" {
			return val
		}
	}
	for _, log := range logs {
		if val := strings.TrimSpace(log.PrescribedLoad); val != "" {
			return val
		}
	}
	if hasExisting && strings.TrimSpace(existing.SuggestedLoad) != "" {
		return existing.SuggestedLoad
	}
	return ""
}

func resolveWaveCurrentWeek(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
) int {
	currentWeek := intOrDefault(block.Data["active_week"], 1)
	if hasExisting && existing.SuggestedWeek > 0 {
		return existing.SuggestedWeek
	}
	if inferredWeek, ok := inferWaveWeekFromLogs(block.Data, logs); ok {
		return inferredWeek
	}
	return currentWeek
}

func inferWaveWeekFromLogs(data map[string]any, logs []CompletedSetLog) (int, bool) {
	if len(logs) == 0 {
		return 0, false
	}

	maxWeek := countConfiguredWaveWeeks(data)
	bestWeek := 0
	bestScore := -1

	for week := 1; week <= maxWeek; week++ {
		score, ok := scoreWaveWeekMatch(data, week, logs)
		if !ok {
			continue
		}
		if score > bestScore {
			bestWeek = week
			bestScore = score
		}
	}

	if bestWeek == 0 {
		return 0, false
	}

	return bestWeek, true
}

func scoreWaveWeekMatch(data map[string]any, week int, logs []CompletedSetLog) (int, bool) {
	repParts := splitPrescriptionParts(asString(data[fmt.Sprintf("week_%d_reps", week)]))
	intensityParts := splitPrescriptionParts(asString(data[fmt.Sprintf("week_%d_intensity", week)]))
	rpeParts := splitPrescriptionParts(asString(data[fmt.Sprintf("week_%d_rpe", week)]))
	totalPrescriptions := maxInt(len(repParts), maxInt(len(intensityParts), len(rpeParts)))
	if totalPrescriptions == 0 {
		return 0, false
	}

	score := 0
	compared := 0
	for index, log := range logs {
		expectedReps := wavePrescriptionPart(repParts, index)
		expectedIntensity := wavePrescriptionPart(intensityParts, index)
		expectedRPE := wavePrescriptionPart(rpeParts, index)

		if expectedReps != "" && normalizeWaveValue(log.PrescribedReps) != "" {
			compared++
			if !waveValuesMatch(expectedReps, log.PrescribedReps) {
				return 0, false
			}
			score += 3
		}
		if expectedRPE != "" && normalizeWaveValue(log.PrescribedRPE) != "" {
			compared++
			if !waveValuesMatch(expectedRPE, log.PrescribedRPE) {
				return 0, false
			}
			score += 2
		}
		if expectedIntensity != "" && normalizeWaveValue(log.PrescribedIntensity) != "" {
			compared++
			if waveValuesMatch(expectedIntensity, log.PrescribedIntensity) {
				score++
			}
		}
	}

	return score, compared > 0
}

func splitPrescriptionParts(value string) []string {
	if strings.TrimSpace(value) == "" {
		return nil
	}
	parts := strings.Split(value, "/")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		normalized := normalizeWaveValue(part)
		if normalized == "" {
			continue
		}
		out = append(out, normalized)
	}
	return out
}

func wavePrescriptionPart(parts []string, index int) string {
	if len(parts) == 0 {
		return ""
	}
	if index < len(parts) {
		return parts[index]
	}
	return parts[len(parts)-1]
}

func waveValuesMatch(expected, actual string) bool {
	return normalizeWaveValue(expected) == normalizeWaveValue(actual)
}

func normalizeWaveValue(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	value = strings.ReplaceAll(value, " ", "")
	value = strings.TrimSuffix(value, "%")
	return value
}

func buildWaveHistoryByBlock(entries []HistoricalCompletedSetLog) map[int][]waveHistorySession {
	type sessionKey struct {
		BlockID   int
		SessionID int
	}

	grouped := make(map[sessionKey]waveHistorySession)
	order := make([]sessionKey, 0, len(entries))
	for _, entry := range entries {
		if entry.WorkflowBlockID == nil {
			continue
		}
		key := sessionKey{BlockID: *entry.WorkflowBlockID, SessionID: entry.SessionID}
		group, exists := grouped[key]
		if !exists {
			group = waveHistorySession{
				SessionID:   entry.SessionID,
				CompletedAt: entry.CompletedAt.UTC().Format(time.RFC3339),
			}
			order = append(order, key)
		}
		group.Logs = append(group.Logs, entry.CompletedSetLog)
		grouped[key] = group
	}

	byBlock := map[int][]waveHistorySession{}
	for _, key := range order {
		group := grouped[key]
		slices.SortFunc(group.Logs, func(a, b CompletedSetLog) int {
			return a.SetIndex - b.SetIndex
		})
		byBlock[key.BlockID] = append(byBlock[key.BlockID], group)
	}

	return byBlock
}

func buildWaveWeekHistoryMetadata(data map[string]any, sessions []waveHistorySession) []map[string]any {
	latestByWeek := map[int]waveHistorySession{}
	maxWeek := countConfiguredWaveWeeks(data)
	for _, session := range sessions {
		week, ok := inferWaveWeekFromLogs(data, session.Logs)
		if !ok || week <= 0 || week > maxWeek {
			continue
		}
		if _, exists := latestByWeek[week]; exists {
			continue
		}
		latestByWeek[week] = session
	}

	history := make([]map[string]any, 0, len(latestByWeek))
	for week := 1; week <= maxWeek; week++ {
		session, exists := latestByWeek[week]
		if !exists {
			continue
		}
		history = append(history, map[string]any{
			"week":                 week,
			"label":                fmt.Sprintf("Week %d", week),
			"session_id":           session.SessionID,
			"completed_at":         session.CompletedAt,
			"actual_reps":          joinLogValues(session.Logs, func(log CompletedSetLog) string { return log.ActualReps }),
			"actual_load":          joinLogValues(session.Logs, func(log CompletedSetLog) string { return log.ActualLoad }),
			"actual_rpe":           joinLogValues(session.Logs, func(log CompletedSetLog) string { return log.ActualRPE }),
			"actual_rir":           joinLogValues(session.Logs, func(log CompletedSetLog) string { return log.ActualRIR }),
			"prescribed_reps":      joinLogValues(session.Logs, func(log CompletedSetLog) string { return log.PrescribedReps }),
			"prescribed_intensity": joinLogValues(session.Logs, func(log CompletedSetLog) string { return log.PrescribedIntensity }),
			"prescribed_rpe":       joinLogValues(session.Logs, func(log CompletedSetLog) string { return log.PrescribedRPE }),
		})
	}

	return history
}

func joinLogValues(logs []CompletedSetLog, extractor func(CompletedSetLog) string) string {
	values := make([]string, 0, len(logs))
	for _, log := range logs {
		value := strings.TrimSpace(extractor(log))
		if value == "" {
			value = "-"
		}
		values = append(values, value)
	}
	return strings.Join(values, " / ")
}

func anyRepTargetMiss(logs []CompletedSetLog, lowerTarget float64) bool {
	if lowerTarget <= 0 {
		return false
	}
	for _, log := range logs {
		repsStr := strings.TrimSpace(log.ActualReps)
		if repsStr == "" {
			repsStr = strings.TrimSpace(log.PrescribedReps)
		}
		if repsStr == "" {
			continue
		}
		actualReps, ok := parseNumberString(repsStr)
		if !ok {
			continue
		}
		if actualReps < lowerTarget {
			return true
		}
	}
	return false
}

func isLinearEasy(hasRPE bool, avgRPE float64, hasRIR bool, avgRIR float64) bool {
	if hasRIR && avgRIR >= 2 {
		return true
	}
	if hasRPE && avgRPE <= 8.5 {
		return true
	}
	return !hasRPE && !hasRIR
}

func isLinearTooHard(hasRPE bool, avgRPE float64, hasRIR bool, avgRIR float64) bool {
	return (hasRIR && avgRIR <= 0.5) || (hasRPE && avgRPE >= 9.5)
}

func countConfiguredWaveWeeks(data map[string]any) int {
	maxWeek := 0
	for week := 1; week <= 6; week++ {
		if asString(data[fmt.Sprintf("week_%d_reps", week)]) != "" ||
			asString(data[fmt.Sprintf("week_%d_intensity", week)]) != "" ||
			asString(data[fmt.Sprintf("week_%d_rpe", week)]) != "" {
			maxWeek = week
		}
	}
	if maxWeek == 0 {
		return 1
	}
	return maxWeek
}

func isWaveEasy(hasTargetRPE bool, targetRPE float64, hasRPE bool, avgRPE float64, hasRIR bool, avgRIR float64) bool {
	if hasRIR && avgRIR >= 2 {
		return true
	}
	if hasTargetRPE && hasRPE && avgRPE <= targetRPE {
		return true
	}
	return !hasRPE && !hasRIR
}

func isWaveTooHard(hasTargetRPE bool, targetRPE float64, hasRPE bool, avgRPE float64, hasRIR bool, avgRIR float64) bool {
	return (hasRIR && avgRIR <= 0.5) || (hasTargetRPE && hasRPE && avgRPE >= targetRPE+1)
}

func formatSignedNumber(value float64) string {
	if value == 0 {
		return "0"
	}
	if value > 0 {
		return "+" + formatMetric(value)
	}
	return formatMetric(value)
}

func currentOffsetToStore(value float64) float64 {
	if value == -0 {
		return 0
	}
	return value
}

func isSkillHighQuality(
	block resolvedWorkflowBlock,
	hasReps bool,
	avgReps float64,
	upperTarget float64,
	hasRPE bool,
	avgRPE float64,
	hasRIR bool,
	avgRIR float64,
) bool {
	if block.NodeTypeSlug == "exercise_timed" {
		return (hasRIR && avgRIR >= 2) || (hasRPE && avgRPE <= 8)
	}
	if hasReps && upperTarget > 0 && avgReps >= upperTarget {
		if hasRIR && avgRIR >= 2 {
			return true
		}
		if hasRPE && avgRPE <= 8.5 {
			return true
		}
	}
	return false
}

func isSkillTooHard(
	hasReps bool,
	avgReps float64,
	lowerTarget float64,
	hasRPE bool,
	avgRPE float64,
	hasRIR bool,
	avgRIR float64,
) bool {
	if lowerTarget > 0 && hasReps && avgReps < lowerTarget {
		return true
	}
	return (hasRIR && avgRIR <= 0.5) || (hasRPE && avgRPE >= 9.5)
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func maxFloat(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func asBool(v any) bool {
	switch val := v.(type) {
	case bool:
		return val
	case string:
		return strings.EqualFold(val, "true") || val == "1"
	case int:
		return val != 0
	case int64:
		return val != 0
	case float64:
		return val != 0
	default:
		return false
	}
}
