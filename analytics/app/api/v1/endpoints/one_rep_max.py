from fastapi import APIRouter, status
from app.models.schemas import OneRepMaxRequest, OneRepMaxResponse
from app.services.one_rep_max import calculate_one_rep_max

router = APIRouter(prefix="/1rm", tags=["One-Rep Max"])


@router.post(
    "",
    response_model=OneRepMaxResponse,
    status_code=status.HTTP_200_OK,
    summary="Calculate 1RM Consensus and Repetitions Projection",
    description="Calculates 1RM using 5 canonical formulas (Brzycki, Epley, Mayhew, Wathen, Lombardi) with RPE/RIR adjustment and 95% confidence intervals.",
)
def compute_one_rep_max(payload: OneRepMaxRequest) -> OneRepMaxResponse:
    return calculate_one_rep_max(payload)
