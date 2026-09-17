import math
import numpy as np

from app.models.schemas import OneRepMaxRequest, OneRepMaxResponse


def calculate_one_rep_max(request: OneRepMaxRequest) -> OneRepMaxResponse:
    """Calculate multi-formula One-Rep Max (1RM) consensus with statistical bounds

    and projected loads for 1 to 12 repetitions.
    """
    load = request.load
    reps = request.reps

    # 1. RPE / RIR effective reps adjustment
    if request.rpe is not None:
        effective_reps = reps + max(0.0, 10.0 - request.rpe)
    elif request.rir is not None:
        effective_reps = reps + max(0.0, float(request.rir))
    else:
        effective_reps = float(reps)

    # If exactly 1 effective rep, the load is directly 1RM
    if math.isclose(effective_reps, 1.0, rel_tol=1e-3):
        return OneRepMaxResponse(
            exercise_name=request.exercise_name,
            input_load=load,
            input_reps=reps,
            effective_reps=1.0,
            brzycki_1rm=round(load, 2),
            epley_1rm=round(load, 2),
            mayhew_1rm=round(load, 2),
            wathen_1rm=round(load, 2),
            lombardi_1rm=round(load, 2),
            consensus_1rm=round(load, 2),
            std_dev=0.0,
            confidence_interval_95=(round(load, 2), round(load, 2)),
            reps_projection={k: round(load / (1.0 + (k - 1) / 30.0), 1) for k in range(1, 13)},
        )

    r = effective_reps

    # 2. Compute canonical formulas
    # Brzycki (capped at r < 36)
    brzycki = load * (36.0 / (37.0 - min(r, 36.0)))

    # Epley
    epley = load * (1.0 + r / 30.0)

    # Mayhew et al.
    mayhew = (100.0 * load) / (52.2 + 41.9 * math.exp(-0.055 * r))

    # Wathen
    wathen = (100.0 * load) / (48.8 + 53.8 * math.exp(-0.075 * r))

    # Lombardi
    lombardi = load * (r**0.10)

    estimates = np.array([brzycki, epley, mayhew, wathen, lombardi], dtype=np.float64)
    consensus = float(np.mean(estimates))
    std_dev = float(np.std(estimates))

    # 95% confidence interval of the mean: mean ± 1.96 * (std / sqrt(N))
    margin = 1.96 * (std_dev / math.sqrt(len(estimates)))
    ci_lower = max(load, consensus - margin)
    ci_upper = consensus + margin

    # Repetition projections for 1 to 12 reps via inverted Epley formula
    reps_projection = {k: round(consensus / (1.0 + (k - 1) / 30.0), 1) for k in range(1, 13)}
    reps_projection[1] = round(consensus, 1)

    return OneRepMaxResponse(
        exercise_name=request.exercise_name,
        input_load=round(load, 2),
        input_reps=reps,
        effective_reps=round(effective_reps, 2),
        brzycki_1rm=round(brzycki, 2),
        epley_1rm=round(epley, 2),
        mayhew_1rm=round(mayhew, 2),
        wathen_1rm=round(wathen, 2),
        lombardi_1rm=round(lombardi, 2),
        consensus_1rm=round(consensus, 2),
        std_dev=round(std_dev, 2),
        confidence_interval_95=(round(ci_lower, 2), round(ci_upper, 2)),
        reps_projection=reps_projection,
    )
