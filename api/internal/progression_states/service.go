package progressionstates

import (
	"context"
	"fmt"
	"regexp"
	"slices"
	"strconv"
	"strings"

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

var numberPattern = regexp.MustCompile(`-?\d+(?:\.\d+)?`)

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

		state, ok := s.buildNextState(block, blockLogs, existingByKey[block.BlockKey], okState(existingByKey, block.BlockKey), in)
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

	ordered := make([]ProgressionState, 0, len(states))
	for _, block := range resolvedBlocks {
		state, exists := stateByKey[block.BlockKey]
		if !exists {
			continue
		}
		state.WorkflowBlockID = block.ID
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
		if !looksLikeSkillProgression(block) {
			return UpsertProgressionStateInput{}, false
		}
		return buildSkillProgressionState(block, logs, existing, hasExisting, session), true
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

func buildLinearProgressionState(
	block resolvedWorkflowBlock,
	logs []CompletedSetLog,
	existing ProgressionState,
	hasExisting bool,
	session ApplySessionProgressionInput,
) UpsertProgressionStateInput {
	lowerTarget, _ := parseRepRange(firstNonEmpty(asString(block.Data["reps"]), logs[0].PrescribedReps))
	setsPlanned := intOrDefault(block.Data["sets"], len(logs))
	increment := parseNumberValue(block.Data["increment"])
	loadUnit := asString(block.Data["load_unit"])

	currentLoad := resolveLinearCurrentLoad(block, logs, existing, hasExisting, loadUnit)
	currentLoadValue, hasCurrentLoad := parseNumberString(currentLoad)
	avgRPE, avgRPELabel, hasRPE := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRPE })
	avgRIR, avgRIRLabel, hasRIR := averageMetric(logs, func(log CompletedSetLog) string { return log.ActualRIR })
	allSetsCompleted := len(logs) >= setsPlanned
	missedTarget := anyRepTargetMiss(logs, lowerTarget)

	outcome := OutcomeMaintain
	suggestedLoad := currentLoad
	summary := "Keep the current load next session."

	switch {
	case missedTarget || !allSetsCompleted || isLinearTooHard(hasRPE, avgRPE, hasRIR, avgRIR):
		outcome = OutcomeReduce
		if hasCurrentLoad && increment > 0 {
			suggestedLoad = formatLoad(maxFloat(currentLoadValue-increment, 0), loadUnit)
		}
		summary = "Reduce the load next session. Reps fell off or effort ran too high."
	case isLinearEasy(hasRPE, avgRPE, hasRIR, avgRIR):
		outcome = OutcomeIncrease
		if hasCurrentLoad && increment > 0 {
			suggestedLoad = formatLoad(currentLoadValue+increment, loadUnit)
		}
		summary = "Add load next session. The work stayed within a manageable effort."
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
			"increment":         increment,
			"load_unit":         loadUnit,
			"progression_rule":  asString(block.Data["progression_rule"]),
			"sets_planned":      setsPlanned,
			"target_reps_lower": lowerTarget,
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
	currentWeek := intOrDefault(block.Data["active_week"], 1)
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
	if hasExisting && strings.TrimSpace(existing.SuggestedLoad) != "" {
		return existing.SuggestedLoad
	}
	if configured := parseNumberValue(block.Data["start_load"]); configured > 0 {
		return formatLoad(configured, loadUnit)
	}
	for _, log := range logs {
		if strings.TrimSpace(log.ActualLoad) != "" {
			return strings.TrimSpace(log.ActualLoad)
		}
	}
	for _, log := range logs {
		if strings.TrimSpace(log.PrescribedLoad) != "" {
			return strings.TrimSpace(log.PrescribedLoad)
		}
	}
	return ""
}

func anyRepTargetMiss(logs []CompletedSetLog, lowerTarget float64) bool {
	if lowerTarget <= 0 {
		return false
	}
	for _, log := range logs {
		if strings.TrimSpace(log.ActualReps) == "" {
			continue
		}
		actualReps, ok := parseNumberString(log.ActualReps)
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
