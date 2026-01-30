-- Create user_preferences table
-- Stores user settings like audio preferences, theme, and timer defaults

CREATE TABLE IF NOT EXISTS public.user_preferences (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    audio_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    voice_type TEXT NOT NULL DEFAULT 'default',
    theme TEXT NOT NULL DEFAULT 'dark',
    default_rest_seconds INTEGER NOT NULL DEFAULT 60,
    countdown_seconds INTEGER NOT NULL DEFAULT 10,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add comment to table
COMMENT ON TABLE public.user_preferences IS 'User preferences and settings';

-- Create index on updated_at for potential sync queries
CREATE INDEX IF NOT EXISTS idx_user_preferences_updated_at ON public.user_preferences(updated_at);

-- Enable Row Level Security
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own preferences

-- Policy for SELECT: Users can read their own preferences
CREATE POLICY "Users can view own preferences"
    ON public.user_preferences
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy for INSERT: Users can create their own preferences
CREATE POLICY "Users can create own preferences"
    ON public.user_preferences
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy for UPDATE: Users can update their own preferences
CREATE POLICY "Users can update own preferences"
    ON public.user_preferences
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy for DELETE: Users can delete their own preferences
CREATE POLICY "Users can delete own preferences"
    ON public.user_preferences
    FOR DELETE
    USING (auth.uid() = user_id);

-- Trigger to automatically update updated_at timestamp
-- Uses handle_updated_at() function created in profiles migration
CREATE TRIGGER set_user_preferences_updated_at
    BEFORE UPDATE ON public.user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
