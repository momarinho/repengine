from app.models.schemas import INOLRequest, INOLSet
from app.services.inol import calculate_inol


def test_inol_single_set():
    # 5 reps at 80% = 5 / (100 - 80) = 0.25
    req = INOLRequest(
        exercise_name="Squat",
        sets=[INOLSet(reps=5, intensity_percentage=80.0)],
    )
    res = calculate_inol(req)

    assert res.exercise_name == "Squat"
    assert res.total_inol == 0.25
    assert res.classification == "recovery"


def test_inol_optimal_session():
    # 3 sets of 5 at 80% = 3 * 0.25 = 0.75 (optimal)
    req = INOLRequest(
        exercise_name="Bench Press",
        sets=[INOLSet(reps=5, intensity_percentage=80.0) for _ in range(3)],
    )
    res = calculate_inol(req)

    assert res.total_inol == 0.75
    assert res.classification == "optimal"


def test_inol_excessive_session():
    # 5 sets of 10 at 75% = 5 * (10 / 25) = 2.0 (excessive)
    req = INOLRequest(
        exercise_name="Deadlift",
        sets=[INOLSet(reps=10, intensity_percentage=75.0) for _ in range(5)],
    )
    res = calculate_inol(req)

    assert res.total_inol == 2.0
    assert res.classification == "excessive"
