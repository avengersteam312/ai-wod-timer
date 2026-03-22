-- Migration: Create timer_reports table
-- Description: Stores anonymous user feedback when AI timer parsing is incorrect

-- Create timer_reports table
CREATE TABLE IF NOT EXISTS public.timer_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_kind TEXT NOT NULL CHECK (report_kind IN ('wrong_workout_type', 'wrong_intervals', 'other')),
    message TEXT,
    original_parsed JSONB NOT NULL,
    edited_config JSONB,
    app_version TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create index on report_kind for filtering
CREATE INDEX IF NOT EXISTS timer_reports_report_kind_idx ON public.timer_reports(report_kind);

-- Create index on created_at for sorting (most recent first)
CREATE INDEX IF NOT EXISTS timer_reports_created_at_idx ON public.timer_reports(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.timer_reports ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Public INSERT allowed, no SELECT (admin-only via service key)
-- Anonymous users can submit reports
CREATE POLICY "Anyone can insert reports"
    ON public.timer_reports
    FOR INSERT
    WITH CHECK (true);

-- No SELECT policy - reports are admin-only via service key
-- This prevents users from reading other reports

-- Grant INSERT permission to anonymous and authenticated users
GRANT INSERT ON public.timer_reports TO anon;
GRANT INSERT ON public.timer_reports TO authenticated;
