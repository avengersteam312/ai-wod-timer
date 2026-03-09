#!/bin/bash
#
# Run backend services with hot reloading.
# Containers are always rebuilt to ensure Dockerfile changes are applied.
#
# Usage:
#   ./scripts/dev.sh              # Run backend
#   ./scripts/dev.sh backend      # Run backend only
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
  *)
    echo "=== Building backend ==="
    docker compose build backend
    echo -e "\n=== Starting backend with hot reload ==="
    echo "Press Ctrl+C to stop"
    docker compose up backend
    ;;
esac
