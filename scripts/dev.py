#!/usr/bin/env python3
"""
Run frontend and backend services with hot reloading.

This script starts both services using Docker Compose with live reloading enabled.

Usage:
    python scripts/dev.py              # Run both frontend and backend
    python scripts/dev.py --backend    # Run backend only
    python scripts/dev.py --frontend   # Run frontend only
    python scripts/dev.py --build      # Rebuild containers before starting
    python scripts/dev.py --down       # Stop all services
"""

import argparse
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent


def run_command(cmd: list[str], description: str = None):
    """Run a command and handle errors."""
    if description:
        print(f"\n=== {description} ===")
    print(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=PROJECT_ROOT)
    return result.returncode == 0


def docker_compose(*args):
    """Run docker compose command."""
    return ["docker", "compose"] + list(args)


def main():
    parser = argparse.ArgumentParser(description="Run development services")
    parser.add_argument("--backend", action="store_true", help="Run backend only")
    parser.add_argument("--frontend", action="store_true", help="Run frontend only")
    parser.add_argument("--build", action="store_true", help="Rebuild containers")
    parser.add_argument("--down", action="store_true", help="Stop all services")
    parser.add_argument("--logs", action="store_true", help="Show logs only (attach to running services)")
    args = parser.parse_args()

    # Stop services
    if args.down:
        run_command(docker_compose("down"), "Stopping services")
        return

    # Show logs only
    if args.logs:
        services = []
        if args.backend:
            services.append("backend")
        elif args.frontend:
            services.append("frontend")
        run_command(docker_compose("logs", "-f", *services), "Showing logs")
        return

    # Determine which services to run
    services = []
    if args.backend and not args.frontend:
        services = ["backend"]
    elif args.frontend and not args.backend:
        services = ["frontend"]
    # If both or neither specified, run all (default)

    # Build if requested
    if args.build:
        build_cmd = docker_compose("build", *services)
        if not run_command(build_cmd, "Building containers"):
            print("Build failed!")
            sys.exit(1)

    # Run services with logs
    up_cmd = docker_compose("up", *services)
    print("\n=== Starting services with hot reload ===")
    print("Press Ctrl+C to stop\n")

    try:
        subprocess.run(up_cmd, cwd=PROJECT_ROOT)
    except KeyboardInterrupt:
        print("\n\nStopping services...")
        run_command(docker_compose("down"))


if __name__ == "__main__":
    main()
