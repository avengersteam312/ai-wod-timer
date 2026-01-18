#!/bin/bash
#
# Run frontend and backend services with hot reloading.
# Containers are always rebuilt to ensure Dockerfile changes are applied.
#
# Usage:
#   ./scripts/dev.sh              # Run both frontend and backend
#   ./scripts/dev.sh backend      # Run backend only
#   ./scripts/dev.sh frontend     # Run frontend only
#   ./scripts/dev.sh down         # Stop all services
#   ./scripts/dev.sh logs         # Attach to running service logs

set -e

cd "$(dirname "$0")/.."

case "$1" in
  down)
    echo "=== Stopping services ==="
    docker compose down
    ;;
  logs)
    docker compose logs -f ${2:-}
    ;;
  backend)
    echo "=== Building backend ==="
    docker compose build backend
    echo -e "\n=== Starting backend with hot reload ==="
    echo "Press Ctrl+C to stop"
    docker compose up backend
    ;;
  frontend)
    echo "=== Building frontend ==="
    docker compose build frontend
    echo -e "\n=== Starting frontend with hot reload ==="
    echo "Press Ctrl+C to stop"
    docker compose up frontend
    ;;
  *)
    echo "=== Building containers ==="
    docker compose build
    echo -e "\n=== Starting services with hot reload ==="
    echo "Press Ctrl+C to stop"
    docker compose up
    ;;
esac
