from datetime import date, timedelta
from app.models.schemas import ACWRDailyWorkload, ACWRRequest
from app.services.workload_acwr import calculate_acwr


def generate_history(loads: list[float]) -> list[ACWRDailyWorkload]:
    base = date(2026, 1, 1)
    return [
        ACWRDailyWorkload(date=base + timedelta(days=i), workload=w)
        for i, w in enumerate(loads)
    ]


def test_acwr_optimal_zone():
    # 28 days of constant 1000 workload -> ACWR = 1.0 (Optimal)
    history = generate_history([1000.0] * 28)
    req = ACWRRequest(history=history, model="coupled")
    res = calculate_acwr(req)

    assert res.zone == "optimal"
    assert 0.95 <= res.acwr_ratio <= 1.05


def test_acwr_danger_zone_spike():
    # 21 days of low workload (500) followed by 7 days of 1500 (spike)
    history = generate_history([500.0] * 21 + [1500.0] * 7)
    req = ACWRRequest(history=history, model="coupled")
    res = calculate_acwr(req)

    # Acute avg = 1500, chronic avg = (21*500 + 7*1500)/28 = 750 -> ACWR = 2.0
    assert res.acwr_ratio >= 1.5
    assert res.zone == "danger_zone"
    assert "immediate deload" in res.recommendation.lower() or "danger zone" in res.risk_assessment.lower()


def test_acwr_undertraining_zone():
    # 21 days of high workload (1500) followed by 7 days of almost nothing (200)
    history = generate_history([1500.0] * 21 + [200.0] * 7)
    req = ACWRRequest(history=history, model="coupled")
    res = calculate_acwr(req)

    assert res.acwr_ratio < 0.8
    assert res.zone == "undertraining"


def test_acwr_ewma_model():
    history = generate_history([1000.0] * 28)
    req = ACWRRequest(history=history, model="ewma")
    res = calculate_acwr(req)

    assert res.zone == "optimal"
    assert 0.9 <= res.acwr_ratio <= 1.1
