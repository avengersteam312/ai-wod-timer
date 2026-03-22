#!/usr/bin/env bash
# Lightweight backend smoke test.
# Usage: ./scripts/smoke_test.sh https://ai-wod-timer-staging.onrender.com
set -euo pipefail

BASE_URL="${1:?Usage: $0 <base_url>}"

echo "Running smoke tests against $BASE_URL..."

# 1. Health check
echo "→ Health check"
HEALTH=$(curl -sf "$BASE_URL/health") || {
  echo "FAIL: /health did not return 200"
  exit 1
}
echo "$HEALTH" | jq -e '.status == "ok"' > /dev/null || {
  echo "FAIL: /health status is not 'ok'"
  echo "$HEALTH"
  exit 1
}
echo "  ✓ /health OK"

# 2. Parse smoke test — real OpenAI call to validate full AI pipeline
echo "→ Parse endpoint (AMRAP)"
RESPONSE=$(curl -sf -X POST "$BASE_URL/api/v1/timer/parse" \
  -H "Content-Type: application/json" \
  -d '{"workout_text": "AMRAP 20 min: 5 pull-ups, 10 push-ups, 15 air squats"}') || {
  echo "FAIL: /api/v1/timer/parse did not return 200"
  exit 1
}
echo "$RESPONSE" | jq -e '.workout_type == "amrap"' > /dev/null || {
  echo "FAIL: parse returned unexpected workout_type"
  echo "$RESPONSE"
  exit 1
}
echo "  ✓ /api/v1/timer/parse OK"

echo "✓ All smoke tests passed"
