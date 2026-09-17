from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_healthcheck():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "repengine-analytics"
    assert "X-Process-Time-Ms" in response.headers


def test_api_1rm_endpoint():
    payload = {
        "exercise_name": "Bench Press",
        "load": 100.0,
        "reps": 5,
        "rpe": 8.5,
    }
    response = client.post("/api/v1/1rm", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["exercise_name"] == "Bench Press"
    assert data["consensus_1rm"] > 100.0
    assert "reps_projection" in data
    assert len(data["reps_projection"]) == 12


def test_api_1rm_validation_error():
    payload = {
        "exercise_name": "Bench Press",
        "load": -10.0,  # Invalid load
        "reps": 0,      # Invalid reps
    }
    response = client.post("/api/v1/1rm", json=payload)
    assert response.status_code == 422


def test_api_acwr_endpoint():
    history = [
        {"date": f"2026-01-{i:02d}", "workload": 1000.0}
        for i in range(1, 29)
    ]
    payload = {
        "exercise_name": "Squat",
        "history": history,
        "model": "coupled",
    }
    response = client.post("/api/v1/acwr", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["zone"] == "optimal"
    assert 0.9 <= data["acwr_ratio"] <= 1.1


def test_api_inol_endpoint():
    payload = {
        "exercise_name": "Deadlift",
        "sets": [
            {"reps": 5, "intensity_percentage": 80.0},
            {"reps": 5, "intensity_percentage": 80.0},
            {"reps": 5, "intensity_percentage": 80.0},
        ],
    }
    response = client.post("/api/v1/inol", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["total_inol"] == 0.75
    assert data["classification"] == "optimal"


def test_api_autoregulation_endpoint():
    payload = {
        "exercise_name": "Squat",
        "progression_type": "linear",
        "load_increment": 2.5,
        "sessions": [
            {
                "session_id": 1,
                "date": "2026-01-01",
                "target_reps": 5,
                "completed_reps": 5,
                "load": 100.0,
                "rpe": 8.0,
                "failed": False,
            }
        ],
    }
    response = client.post("/api/v1/autoregulation", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["recommended_action"] == "increase_load"
    assert data["recommended_load"] == 102.5
