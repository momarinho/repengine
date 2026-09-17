from app.models.schemas import AutoregulationRequest, AutoregulationResponse


def calculate_autoregulation(request: AutoregulationRequest) -> AutoregulationResponse:
    """Evaluate training session trends to determine autoregulated progression,

    failure management, and deload requirements.
    """
    sessions = sorted(request.sessions, key=lambda s: s.date)
    last_session = sessions[-1]
    current_load = last_session.load
    increment = request.load_increment

    # Check consecutive failures from the end
    consecutive_failures = 0
    for s in reversed(sessions):
        if s.failed or s.completed_reps < s.target_reps:
            consecutive_failures += 1
        else:
            break

    # RPE evaluations
    last_rpe = last_session.rpe if last_session.rpe is not None else 8.0

    if consecutive_failures >= 3:
        # Standard periodization reset (e.g. GZCLP / 5/3/1 stall protocol)
        rec_action = "reset_cycle"
        rec_load = round(current_load * 0.85, 1)
        reasoning = (
            f"Detected 3 consecutive failed sessions for {request.exercise_name}. "
            f"Resetting cycle by 15% (to {rec_load} kg) to dissipate systemic fatigue and rebuild momentum."
        )
        confidence = 0.95

    elif consecutive_failures == 2:
        # Deload volume or intensity
        rec_action = "deload_intensity"
        rec_load = round(current_load * 0.90, 1)
        reasoning = (
            f"Detected 2 consecutive stalled sessions. Recommend a 10% load reduction (to {rec_load} kg) "
            "or volume cut before advancing."
        )
        confidence = 0.85

    elif consecutive_failures == 1:
        # Single failure: repeat the same weight
        rec_action = "maintain_load"
        rec_load = current_load
        reasoning = (
            f"Missed target reps on the last session ({last_session.completed_reps}/{last_session.target_reps}). "
            "Maintain current load for the next attempt."
        )
        confidence = 0.80

    else:
        # All reps completed!
        if last_rpe <= 8.5:
            # Clean success with velocity to spare -> increase load
            rec_action = "increase_load"
            rec_load = round(current_load + increment, 1)
            reasoning = (
                f"Target reps accomplished with submaximal RPE ({last_rpe}). "
                f"Progressive overload recommended: +{increment} kg (target: {rec_load} kg)."
            )
            confidence = 0.90
        elif last_rpe >= 9.5:
            # Grinder: completed reps but near absolute failure
            rec_action = "maintain_load"
            rec_load = current_load
            reasoning = (
                f"All reps completed, but effort was near maximal (RPE {last_rpe}). "
                "Consolidate at current load before incrementing further."
            )
            confidence = 0.85
        else:
            # Moderate RPE (8.5 - 9.0)
            rec_action = "increase_load"
            rec_load = round(current_load + increment, 1)
            reasoning = f"Target achieved. Advance load by +{increment} kg."
            confidence = 0.85

    return AutoregulationResponse(
        exercise_name=request.exercise_name,
        recommended_action=rec_action,
        current_load=round(current_load, 1),
        recommended_load=round(rec_load, 1),
        reasoning=reasoning,
        confidence_score=round(confidence, 2),
    )
