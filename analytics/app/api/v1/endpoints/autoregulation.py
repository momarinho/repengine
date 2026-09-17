from fastapi import APIRouter, status
from app.models.schemas import AutoregulationRequest, AutoregulationResponse
from app.services.autoregulation import calculate_autoregulation

router = APIRouter(prefix="/autoregulation", tags=["Autoregulation & Deloads"])


@router.post(
    "",
    response_model=AutoregulationResponse,
    status_code=status.HTTP_200_OK,
    summary="Evaluate Performance Trend and Suggest Next Load / Deload",
    description="Analyzes chronological workout session logs to determine progressive overload increments, consolidation, or deloads.",
)
def compute_autoregulation(payload: AutoregulationRequest) -> AutoregulationResponse:
    return calculate_autoregulation(payload)
