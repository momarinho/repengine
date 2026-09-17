from datetime import date
from app.models.schemas import AutoregulationRequest, AutoregulationSessionLog
from app.services.autoregulation import calculate_autoregulation


def test_autoregulation_increase_load():
    sessions = [
        AutoregulationSessionLog(
            session_id=1,
            date=date(2026, 1, 1),
            target_reps=5,
            completed_reps=5,
            load=100.0,
            rpe=8.0,
        ),
        AutoregulationSessionLog(
            session_id=2,
            date=date(2026, 1, 4),
            target_reps=5,
            completed_reps=5,
            load=100.0,
            rpe=8.0,
        ),
    ]
    req = AutoregulationRequest(
        exercise_name="Squat",
        sessions=sessions,
        load_increment=2.5,
    )
    res = calculate_autoregulation(req)

    assert res.recommended_action == "increase_load"
    assert res.recommended_load == 102.5


def test_autoregulation_maintain_on_high_rpe():
    sessions = [
        AutoregulationSessionLog(
            session_id=1,
            date=date(2026, 1, 1),
            target_reps=5,
            completed_reps=5,
            load=100.0,
            rpe=9.8,
        )
    ]
    req = AutoregulationRequest(
        exercise_name="Bench Press",
        sessions=sessions,
        load_increment=2.5,
    )
    res = calculate_autoregulation(req)

    assert res.recommended_action == "maintain_load"
    assert res.recommended_load == 100.0


def test_autoregulation_single_failure_maintains():
    sessions = [
        AutoregulationSessionLog(
            session_id=1,
            date=date(2026, 1, 1),
            target_reps=5,
            completed_reps=4,
            load=100.0,
            rpe=10.0,
            failed=True,
        )
    ]
    req = AutoregulationRequest(
        exercise_name="Overhead Press",
        sessions=sessions,
    )
    res = calculate_autoregulation(req)

    assert res.recommended_action == "maintain_load"
    assert res.recommended_load == 100.0


def test_autoregulation_three_failures_triggers_reset():
    sessions = [
        AutoregulationSessionLog(
            session_id=1, date=date(2026, 1, 1), target_reps=5, completed_reps=4, load=100.0, failed=True
        ),
        AutoregulationSessionLog(
            session_id=2, date=date(2026, 1, 4), target_reps=5, completed_reps=4, load=100.0, failed=True
        ),
        AutoregulationSessionLog(
            session_id=3, date=date(2026, 1, 7), target_reps=5, completed_reps=3, load=100.0, failed=True
        ),
    ]
    req = AutoregulationRequest(
        exercise_name="Squat",
        sessions=sessions,
    )
    res = calculate_autoregulation(req)

    assert res.recommended_action == "reset_cycle"
    assert res.recommended_load == 85.0  # 100 * 0.85
