import numpy as np

from app.models.schemas import ACWRRequest, ACWRResponse


def calculate_acwr(request: ACWRRequest) -> ACWRResponse:
    """Calculate Acute:Chronic Workload Ratio (ACWR) to quantify training fatigue

    and injury risk based on sports science consensus (Gabbett et al.).
    """
    sorted_history = sorted(request.history, key=lambda x: x.date)
    workloads = np.array([item.workload for item in sorted_history], dtype=np.float64)

    acute_n = request.acute_days
    chronic_n = min(request.chronic_days, len(workloads))

    if request.model == "ewma":
        # Exponentially Weighted Moving Average model
        lambda_acute = 2.0 / (acute_n + 1.0)
        lambda_chronic = 2.0 / (chronic_n + 1.0)

        ewma_acute = workloads[0]
        ewma_chronic = workloads[0]

        for w in workloads[1:]:
            ewma_acute = w * lambda_acute + (1.0 - lambda_acute) * ewma_acute
            ewma_chronic = w * lambda_chronic + (1.0 - lambda_chronic) * ewma_chronic

        acute_val = float(ewma_acute)
        chronic_val = float(max(1.0, ewma_chronic))
    else:
        # Coupled rolling window model
        acute_window = workloads[-acute_n:]
        chronic_window = workloads[-chronic_n:]

        acute_val = float(np.mean(acute_window))
        chronic_val = float(max(1.0, np.mean(chronic_window)))

    acwr = acute_val / chronic_val

    # Classify according to sports science consensus
    if acwr < 0.8:
        zone = "undertraining"
        risk = "Fitness is decaying while acute stimulus is low. Watch out for sudden load spikes."
        rec = "Gradually increase weekly volume to enter the optimal adaptation zone."
    elif 0.8 <= acwr <= 1.3:
        zone = "optimal"
        risk = "Sweet Spot: Workload is balanced with chronic fitness preparedness."
        rec = "Maintain steady linear progression; injury risk is minimized and adaptation is optimal."
    elif 1.3 < acwr <= 1.5:
        zone = "elevated_risk"
        risk = "Elevated Risk: Acute fatigue is accumulating significantly faster than chronic capacity."
        rec = "Cap volume increments. Prioritize sleep and recovery before adding extra sets."
    else:
        zone = "danger_zone"
        risk = "Danger Zone (ACWR > 1.5): Acute load spike detected. High risk of overtraining or injury."
        rec = "Implement an immediate deload: reduce intensity by 10-15% or drop set volume by 40%."

    return ACWRResponse(
        exercise_name=request.exercise_name,
        acute_workload=round(acute_val, 2),
        chronic_workload=round(chronic_val, 2),
        acwr_ratio=round(acwr, 2),
        zone=zone,
        risk_assessment=risk,
        recommendation=rec,
    )
