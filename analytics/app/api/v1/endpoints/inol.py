from fastapi import APIRouter, status
from app.models.schemas import INOLRequest, INOLResponse
from app.services.inol import calculate_inol

router = APIRouter(prefix="/inol", tags=["INOL Volume / Intensity"])


@router.post(
    "",
    response_model=INOLResponse,
    status_code=status.HTTP_200_OK,
    summary="Compute Intensity Number of Lifts (INOL)",
    description="Calculates cumulative session INOL to classify fatigue stimulus and recovery requirements.",
)
def compute_inol(payload: INOLRequest) -> INOLResponse:
    return calculate_inol(payload)
