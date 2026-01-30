-- Migration: Create workouts table
-- Description: Stores parsed workout configurations for users

-- Create workouts table
CREATE TABLE IF NOT EXISTS public.workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    raw_input TEXT,
    parsed_config JSONB NOT NULL,
    is_favorite BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS workouts_user_id_idx ON public.workouts(user_id);

-- Create index on updated_at for sorting
CREATE INDEX IF NOT EXISTS workouts_updated_at_idx ON public.workouts(updated_at DESC);

-- Create index on is_favorite for filtering favorites
CREATE INDEX IF NOT EXISTS workouts_is_favorite_idx ON public.workouts(user_id, is_favorite) WHERE is_favorite = TRUE;

-- Enable Row Level Security
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own workouts
CREATE POLICY "Users can view own workouts"
    ON public.workouts
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own workouts"
    ON public.workouts
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workouts"
    ON public.workouts
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own workouts"
    ON public.workouts
    FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger to auto-update updated_at on row changes (reuses handle_updated_at function from profiles migration)
CREATE TRIGGER set_workouts_updated_at
    BEFORE UPDATE ON public.workouts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Grant permissions
GRANT ALL ON public.workouts TO authenticated;
