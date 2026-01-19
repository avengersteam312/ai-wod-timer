from fastapi import APIRouter
from app.api.v1.endpoints import timer, auth

api_router = APIRouter()

api_router.include_router(timer.router, prefix="/timer", tags=["timer"])
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
