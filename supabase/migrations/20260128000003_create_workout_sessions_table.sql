-- Migration: Create workout_sessions table
-- Description: Tracks completed workout history and session states

-- Create workout_sessions table
CREATE TABLE IF NOT EXISTS public.workout_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_id UUID REFERENCES public.workouts(id) ON DELETE SET NULL,
    workout_snapshot JSONB NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    status TEXT NOT NULL DEFAULT 'in_progress',

    -- Status check constraint: only allow valid status values
    CONSTRAINT workout_sessions_status_check CHECK (status IN ('in_progress', 'completed', 'abandoned'))
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS workout_sessions_user_id_idx ON public.workout_sessions(user_id);

-- Create index on started_at for sorting history
CREATE INDEX IF NOT EXISTS workout_sessions_started_at_idx ON public.workout_sessions(started_at DESC);

-- Create index on status for filtering
CREATE INDEX IF NOT EXISTS workout_sessions_status_idx ON public.workout_sessions(user_id, status);

-- Enable Row Level Security
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own sessions
CREATE POLICY "Users can view own sessions"
    ON public.workout_sessions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
    ON public.workout_sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions"
    ON public.workout_sessions
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions"
    ON public.workout_sessions
    FOR DELETE
    USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.workout_sessions TO authenticated;
