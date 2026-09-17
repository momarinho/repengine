from datetime import date as dt_date
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: str = "ok"
    service: str = "repengine-analytics"
    version: str = "0.1.0"
    env: str = "development"


class OneRepMaxRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str = Field(..., min_length=1, max_length=100, description="Name of the exercise (e.g., Squat)")
    load: float = Field(..., gt=0, description="Load in kg or lbs used in the set")
    reps: int = Field(..., ge=1, le=50, description="Number of repetitions completed")
    rpe: float | None = Field(default=None, ge=5.0, le=10.0, description="Rate of Perceived Exertion (5.0 to 10.0)")
    rir: float | None = Field(default=None, ge=0.0, le=5.0, description="Reps in Reserve (0 to 5)")


class OneRepMaxResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str
    input_load: float
    input_reps: int
    effective_reps: float
    brzycki_1rm: float
    epley_1rm: float
    mayhew_1rm: float
    wathen_1rm: float
    lombardi_1rm: float
    consensus_1rm: float
    std_dev: float
    confidence_interval_95: tuple[float, float]
    reps_projection: dict[int, float]


class ACWRDailyWorkload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    date: dt_date = Field(..., description="Date of training session")
    workload: float = Field(..., ge=0, description="Total volume load (load * reps * sets) or RPE load")


class ACWRRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str | None = Field(default=None, description="Optional filter by exercise")
    history: list[ACWRDailyWorkload] = Field(..., min_length=7, description="Time series of training volume logs")
    acute_days: int = Field(default=7, ge=3, le=14, description="Acute workload window in days (default 7)")
    chronic_days: int = Field(default=28, ge=14, le=60, description="Chronic workload window in days (default 28)")
    model: Literal["coupled", "ewma"] = Field(default="coupled", description="Coupled rolling average or EWMA")


class ACWRResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str | None
    acute_workload: float
    chronic_workload: float
    acwr_ratio: float
    zone: Literal["undertraining", "optimal", "elevated_risk", "danger_zone"]
    risk_assessment: str
    recommendation: str


class INOLSet(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reps: int = Field(..., ge=1, le=50, description="Reps performed in this set")
    intensity_percentage: float = Field(
        ..., gt=0.0, le=100.0, description="Percentage of 1RM (e.g. 80.0 for 80% 1RM)"
    )


class INOLRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str = Field(..., min_length=1, max_length=100)
    sets: list[INOLSet] = Field(..., min_length=1, description="List of sets performed in this workout session")


class INOLResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str
    total_inol: float
    classification: Literal["recovery", "optimal", "high_fatigue", "excessive"]
    recovery_recommendation: str


class AutoregulationSessionLog(BaseModel):
    model_config = ConfigDict(extra="forbid")

    session_id: int
    date: dt_date
    target_reps: int = Field(..., ge=1)
    completed_reps: int = Field(..., ge=0)
    load: float = Field(..., gt=0)
    rpe: float | None = Field(default=None, ge=5.0, le=10.0)
    failed: bool = False


class AutoregulationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str = Field(..., min_length=1, max_length=100)
    progression_type: Literal["linear", "rpe_autoregulated"] = Field(default="linear")
    sessions: list[AutoregulationSessionLog] = Field(..., min_length=1)
    load_increment: float = Field(default=2.5, gt=0, description="Default increment step (e.g., 2.5 kg)")


class AutoregulationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    exercise_name: str
    recommended_action: Literal[
        "increase_load", "maintain_load", "deload_volume", "deload_intensity", "reset_cycle"
    ]
    current_load: float
    recommended_load: float
    reasoning: str
    confidence_score: float
