import pytest
from app.models.schemas import OneRepMaxRequest
from app.services.one_rep_max import calculate_one_rep_max


def test_one_rep_max_single_rep():
    req = OneRepMaxRequest(exercise_name="Bench Press", load=100.0, reps=1)
    res = calculate_one_rep_max(req)

    assert res.exercise_name == "Bench Press"
    assert res.input_load == 100.0
    assert res.input_reps == 1
    assert res.consensus_1rm == 100.0
    assert res.reps_projection[1] == 100.0
    assert res.std_dev == 0.0


def test_one_rep_max_multiple_reps():
    req = OneRepMaxRequest(exercise_name="Squat", load=100.0, reps=5)
    res = calculate_one_rep_max(req)

    assert res.exercise_name == "Squat"
    # Epley for 100x5 is 100 * (1 + 5/30) = 116.67
    assert 114.0 <= res.consensus_1rm <= 120.0
    assert res.confidence_interval_95[0] < res.consensus_1rm < res.confidence_interval_95[1]
    assert len(res.reps_projection) == 12
    assert res.reps_projection[1] > res.reps_projection[10]


def test_one_rep_max_rpe_adjustment():
    # 5 reps at RPE 8 means 2 reps in reserve -> effective reps = 7
    req = OneRepMaxRequest(exercise_name="Deadlift", load=150.0, reps=5, rpe=8.0)
    res = calculate_one_rep_max(req)

    assert res.effective_reps == 7.0
    # Effective 7 reps at 150kg should yield higher 1RM than 5 reps at 150kg
    assert res.consensus_1rm > 175.0


def test_one_rep_max_rir_adjustment():
    # 3 reps at RIR 3 -> effective reps = 6
    req = OneRepMaxRequest(exercise_name="Overhead Press", load=60.0, reps=3, rir=3.0)
    res = calculate_one_rep_max(req)

    assert res.effective_reps == 6.0
    assert res.consensus_1rm > 65.0
