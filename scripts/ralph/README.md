# Ralph - Autonomous AI Agent Loop

Ralph is an autonomous AI agent loop that runs AI coding tools (Cursor CLI, Amp, or Claude Code) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://github.com/snarktank/ralph).

## Prerequisites

* One of the following AI coding tools installed and authenticated:
  * **Cursor CLI** (recommended, already installed ✅) - `curl https://cursor.com/install -fsS | bash`
    * **Authentication required**: Run `agent login` (browser-based) or set `CURSOR_API_KEY` environment variable
    * **Note**: Cursor CLI requires separate authentication from Cursor IDE
  * **Claude Code** - `npm install -g @anthropic-ai/claude-code`
  * **Amp CLI** (optional) - `curl -fsSL https://ampcode.com/install.sh | bash` or `npm install -g @sourcegraph/amp`
* `jq` installed (`brew install jq` on macOS) - ✅ Already installed
* A git repository (already set up)

### Cursor CLI Authentication

**Important**: Cursor CLI needs separate authentication from Cursor IDE. Choose one method:

**Option 1: Browser Login (Recommended)**
```bash
agent login
```
This opens your browser to authenticate. Your credentials are stored locally.

**Option 2: API Key**
1. Get API key: Go to [Cursor Dashboard](https://cursor.com/dashboard) → Integrations → User API Keys
2. Set environment variable:
   ```bash
   export CURSOR_API_KEY=your_api_key_here
   ```
   Or add to your `~/.zshrc` or `~/.bashrc`:
   ```bash
   echo 'export CURSOR_API_KEY=your_api_key_here' >> ~/.zshrc
   source ~/.zshrc
   ```

**Verify authentication:**
```bash
agent status
```

## Quick Start

### 1. Create a PRD

Create a Product Requirements Document (PRD) in JSON format. You can start from the example:

```bash
cp scripts/ralph/prd.json.example scripts/ralph/prd.json
```

Then edit `scripts/ralph/prd.json` with your feature requirements. Each user story should:
- Be small enough to complete in one context window
- Have clear acceptance criteria
- Include quality checks (typecheck, tests, browser verification for UI)
- Have a priority number (lower = higher priority)

### 2. Run Ralph

```bash
# Using Cursor CLI (default, recommended)
./scripts/ralph/ralph.sh [max_iterations]

# Using Claude Code
./scripts/ralph/ralph.sh --tool claude [max_iterations]

# Using Amp
./scripts/ralph/ralph.sh --tool amp [max_iterations]
```

Default is 10 iterations. Ralph will:

1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances |
| `prompt.md` | Prompt template for Amp |
| `ralphAgentInstructions.md` | Prompt template for Claude Code / Cursor |
| `prd.json` | User stories with passes status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |

## Workflow Details

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** with clean context. The only memory between iterations is:

* Git history (commits from previous iterations)
* `progress.txt` (learnings and context)
* `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

**Right-sized stories:**
* Add a database column and migration
* Add a UI component to an existing page
* Update a server action with new logic
* Add a filter dropdown to a list

**Too big (split these):**
* "Build the entire dashboard"
* "Add authentication"
* "Refactor the API"

### Quality Checks

Ralph runs these checks before committing:

**Backend:**
```bash
cd backend
pytest
python -m py_compile app/**/*.py
```

**Frontend:**
```bash
cd frontend
npx vue-tsc --noEmit
```

### Browser Verification

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use browser tools to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## PRD Format

```json
{
  "project": "AI Workout Timer",
  "branchName": "ralph/feature-name",
  "description": "Feature description",
  "userStories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "As a user, I want...",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

## Debugging

Check current state:

```bash
# See which stories are done
cat scripts/ralph/prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat scripts/ralph/progress.txt

# Check git history
git log --oneline -10
```

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `scripts/ralph/archive/YYYY-MM-DD-feature-name/`.

## Using with Cursor

### Option 1: Cursor CLI (Recommended)

The default tool is Cursor CLI (`agent` command), which provides the best integration:

```bash
# Install Cursor CLI if not already installed
curl https://cursor.com/install -fsS | bash

# Run Ralph (uses Cursor CLI by default)
./scripts/ralph/ralph.sh [max_iterations]
```

### Option 2: Manual in Cursor IDE

You can also run Ralph manually in the Cursor IDE:

1. Open Cursor
2. Load the `scripts/ralph/ralphAgentInstructions.md` file
3. Follow the instructions in the prompt
4. Ralph will work through stories one at a time

The bash script (`ralph.sh`) is useful for fully autonomous runs, but you can also guide Ralph manually through Cursor's AI features.

## Project-Specific Notes

This project uses:
- **Backend**: FastAPI + PostgreSQL + OpenAI
- **Frontend**: Vue 3 + TypeScript + Vite
- **Testing**: pytest (backend), vue-tsc (frontend type checking)

Quality checks are configured in `prompt.md` and `ralphAgentInstructions.md` to match this stack.

## Tool Comparison

| Tool | Status | Best For |
|------|--------|----------|
| **Cursor CLI** | ✅ Installed | **Recommended** - Best integration with Cursor IDE |
| **Claude Code** | ⚠️ Not installed | Alternative option if you prefer Claude Code |
| **Amp CLI** | ⚠️ Not installed | Alternative option (requires separate setup) |

**Recommendation**: Since you're using Cursor IDE, stick with Cursor CLI (already installed). It provides the best integration and is the default tool.

## References

* [Original Ralph Repository](https://github.com/snarktank/ralph)
* [Geoffrey Huntley's Ralph Article](https://geoffreyhuntley.com/ralph/)
* [Cursor CLI Documentation](https://cursor.com/docs/cli/overview)
* [Amp Documentation](https://docs.ampcode.com/)
* [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
