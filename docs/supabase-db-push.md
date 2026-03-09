# Supabase: push migrations (with project reference)

Your project URL: **https://[project-id].supabase.co**  
Project reference: **`[project-id]`** (find it in Supabase Dashboard → Settings → General)

## 1. Install Supabase CLI (if needed)

```bash
# macOS
brew install supabase/tap/supabase
```

## 2. Link and push

From the **repo root** (`ai-wod-timer`):

```bash
cd /path/to/ai-wod-timer

# Link to your remote project (replace [project-id] with your ref; you’ll be prompted for the database password from Supabase Dashboard → Settings → Database)
supabase link --project-ref [project-id]

# Push all pending migrations (adds missing columns to workouts and workout_sessions)
supabase db push
```

After a successful push, the last migration in the dashboard should show the new migration names (e.g. `add_workout_sessions_notes_and_extra_columns`, `add_workouts_movements_and_extra_columns`).

## 3. If you don’t use the CLI

Run the two migration SQL scripts by hand in [Supabase Dashboard](https://supabase.com/dashboard) → your project → **SQL Editor**. See the migration files in `supabase/migrations/` (the two `20260305...` files).
