from fastapi import APIRouter, status
from app.models.schemas import ACWRRequest, ACWRResponse
from app.services.workload_acwr import calculate_acwr

router = APIRouter(prefix="/acwr", tags=["Workload & ACWR"])


@router.post(
    "",
    response_model=ACWRResponse,
    status_code=status.HTTP_200_OK,
    summary="Compute Acute:Chronic Workload Ratio",
    description="Computes ACWR using either coupled rolling windows or exponentially weighted moving average (EWMA) models to assess fatigue and injury risk.",
)
def compute_acwr(payload: ACWRRequest) -> ACWRResponse:
    return calculate_acwr(payload)
