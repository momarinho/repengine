from fastapi import APIRouter

from app.api.v1.endpoints.acwr import router as acwr_router
from app.api.v1.endpoints.autoregulation import router as autoregulation_router
from app.api.v1.endpoints.inol import router as inol_router
from app.api.v1.endpoints.one_rep_max import router as one_rep_max_router

api_v1_router = APIRouter(prefix="/api/v1")

api_v1_router.include_router(one_rep_max_router)
api_v1_router.include_router(acwr_router)
api_v1_router.include_router(inol_router)
api_v1_router.include_router(autoregulation_router)
