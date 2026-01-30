#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./scripts/ralph/ralph.sh [--tool cursor|claude|amp] [max_iterations]

set -e

# Parse arguments
TOOL="cursor" # Default to cursor CLI (recommended for Cursor users)
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "cursor" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'cursor', 'claude', or 'amp'."
  echo "  'cursor' - Cursor CLI (agent command) - Recommended"
  echo "  'claude' - Claude Code CLI"
  echo "  'amp'    - Amp CLI"
  exit 1
fi

# Get script directory (ralph.sh location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is two levels up from scripts/ralph/
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Change to project root
cd "$PROJECT_ROOT"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "  Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"
echo "Project root: $PROJECT_ROOT"
echo "PRD file: $PRD_FILE"

# Check authentication for Cursor CLI
if [[ "$TOOL" == "cursor" ]]; then
  echo ""
  echo "Checking Cursor CLI authentication..."
  if ! agent status &>/dev/null; then
    echo ""
    echo "⚠️  Cursor CLI authentication required!"
    echo ""
    echo "Please authenticate using one of these methods:"
    echo "  1. Run: agent login (opens browser)"
    echo "  2. Set: export CURSOR_API_KEY=your_api_key"
    echo ""
    echo "Get API key from: https://cursor.com/dashboard → Integrations → User API Keys"
    echo ""
    exit 1
  fi
  echo "✅ Cursor CLI authenticated"
fi

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo " Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "cursor" ]]; then
    # Cursor CLI: use non-interactive mode with prompt file
    # Read prompt content and pass to agent command
    PROMPT_FILE="$SCRIPT_DIR/ralphAgentInstructions.md"
    if [ ! -f "$PROMPT_FILE" ]; then
      echo "Error: Prompt file not found: $PROMPT_FILE"
      exit 1
    fi
    PROMPT_CONTENT=$(cat "$PROMPT_FILE" 2>&1) || true
    OUTPUT=$(agent -p "$PROMPT_CONTENT" --output-format text 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  else
    # Claude Code: use --dangerously-skip-permissions for autonomous operation
    PROMPT_FILE="$SCRIPT_DIR/ralphAgentInstructions.md"
    if [ ! -f "$PROMPT_FILE" ]; then
      echo "Error: Prompt file not found: $PROMPT_FILE"
      exit 1
    fi
    OUTPUT=$(claude --dangerously-skip-permissions --print < "$PROMPT_FILE" 2>&1 | tee /dev/stderr) || true
  fi
  
  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
