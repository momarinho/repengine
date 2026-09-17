import time
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.v1.router import api_v1_router
from app.config import settings
from app.models.schemas import HealthResponse

app = FastAPI(
    title=settings.app_name,
    version=settings.version,
    description="Microservice providing sports science analytical modeling, ACWR fatigue tracking, 1RM consensus, INOL monitoring, and autoregulation recommendations for RepEngine.",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.perf_counter()
    response = await call_next(request)
    process_time = (time.perf_counter() - start_time) * 1000
    response.headers["X-Process-Time-Ms"] = f"{process_time:.2f}"
    return response


@app.get(
    "/health",
    response_model=HealthResponse,
    tags=["System"],
    summary="Healthcheck probe",
)
def healthcheck() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="repengine-analytics",
        version=settings.version,
        env=settings.app_env,
    )


app.include_router(api_v1_router)
