from app.models.schemas import INOLRequest, INOLResponse


def calculate_inol(request: INOLRequest) -> INOLResponse:
    """Calculate Intensity Number of Lifts (INOL) for a given session.

    Formula: INOL = Reps / (100 - Intensity_Percentage)
    """
    total_inol = 0.0

    for s in request.sets:
        # Intensity percentage must be < 100 to avoid division by zero
        intensity = min(s.intensity_percentage, 99.0)
        denom = 100.0 - intensity
        set_inol = s.reps / denom
        total_inol += set_inol

    total_inol = round(total_inol, 2)

    if total_inol < 0.4:
        classification = "recovery"
        rec = "Light stimulus. Excellent for recovery days, technique work, or dynamic effort."
    elif 0.4 <= total_inol <= 1.0:
        classification = "optimal"
        rec = "Optimal stimulus. Standard productive training session with predictable 48h recovery."
    elif 1.0 < total_inol <= 1.5:
        classification = "high_fatigue"
        rec = "Challenging session. Expect residual neuromuscular fatigue for 48-72 hours."
    else:
        classification = "excessive"
        rec = "Excessive stimulus (>1.5 INOL). High risk of systemic exhaustion and stalled progression."

    return INOLResponse(
        exercise_name=request.exercise_name,
        total_inol=total_inol,
        classification=classification,
        recovery_recommendation=rec,
    )
