from fastapi import APIRouter
from app.api.v1.endpoints import timer

api_router = APIRouter()

api_router.include_router(timer.router, prefix="/timer", tags=["timer"])
