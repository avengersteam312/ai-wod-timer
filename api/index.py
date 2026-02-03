"""
Vercel Serverless Function Entry Point

Exposes the FastAPI app for Vercel's Python runtime.
"""
import sys
from pathlib import Path

# Add backend to Python path
backend_path = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_path))

from app.main import app

# Vercel expects 'app' export
