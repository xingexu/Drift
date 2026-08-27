-- =========================================================================
-- Drift – Schema V3: Desktop App Support
-- Run this migration after schema-full.sql
-- =========================================================================

-- ---------------------------------------------------------------------------
-- Add name column to user_profiles
-- ---------------------------------------------------------------------------

ALTER TABLE user_profiles ADD COLUMN IF NOT EXISTS name text;

-- ---------------------------------------------------------------------------
-- App Activity Sessions (desktop tracking — replaces browser tab tracking)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app_sessions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_time timestamptz NOT NULL DEFAULT now(),
  end_time timestamptz,
  total_duration_ms bigint DEFAULT 0,
  productive_time_ms bigint DEFAULT 0,
  neutral_time_ms bigint DEFAULT 0,
  distraction_time_ms bigint DEFAULT 0,
  drift_score real DEFAULT 0,
  app_switch_count integer DEFAULT 0,
  unique_apps integer DEFAULT 0,
  platform text NOT NULL DEFAULT 'desktop' CHECK (platform IN ('desktop', 'web', 'extension')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_sessions_user_time ON app_sessions (user_id, start_time DESC);

-- ---------------------------------------------------------------------------
-- App Activity Events (individual app usage windows)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id bigint REFERENCES app_sessions(id) ON DELETE CASCADE,
  app_name text NOT NULL,
  window_title text,
  url text,
  is_browser boolean NOT NULL DEFAULT false,
  category text NOT NULL DEFAULT 'neutral' CHECK (category IN ('productive', 'neutral', 'distraction')),
  start_time timestamptz NOT NULL DEFAULT now(),
  end_time timestamptz,
  duration_ms bigint DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_events_user_time ON app_events (user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_app_events_session ON app_events (session_id);
CREATE INDEX IF NOT EXISTS idx_app_events_app ON app_events (user_id, app_name);

-- ---------------------------------------------------------------------------
-- App Classification Rules (user-customizable)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS app_rules (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pattern text NOT NULL,         -- App name or domain pattern
  pattern_type text NOT NULL DEFAULT 'exact' CHECK (pattern_type IN ('exact', 'contains', 'regex')),
  target text NOT NULL DEFAULT 'app' CHECK (target IN ('app', 'domain')),
  category text NOT NULL CHECK (category IN ('productive', 'neutral', 'distraction')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, pattern, target)
);

CREATE INDEX IF NOT EXISTS idx_app_rules_user ON app_rules (user_id);

-- ---------------------------------------------------------------------------
-- Study Sessions (Pomodoro / timed focus)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS study_sessions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject text,
  focus_duration_min integer NOT NULL DEFAULT 25,
  break_duration_min integer NOT NULL DEFAULT 5,
  sessions_completed integer NOT NULL DEFAULT 0,
  total_focus_time_ms bigint NOT NULL DEFAULT 0,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_study_sessions_user_time ON study_sessions (user_id, started_at DESC);

-- ---------------------------------------------------------------------------
-- Daily Aggregates (for fast dashboard loading)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS daily_aggregates (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  total_tracked_ms bigint NOT NULL DEFAULT 0,
  productive_ms bigint NOT NULL DEFAULT 0,
  neutral_ms bigint NOT NULL DEFAULT 0,
  distraction_ms bigint NOT NULL DEFAULT 0,
  drift_score real DEFAULT 0,
  session_count integer NOT NULL DEFAULT 0,
  app_switch_count integer NOT NULL DEFAULT 0,
  top_apps jsonb NOT NULL DEFAULT '[]',
  study_sessions integer NOT NULL DEFAULT 0,
  study_focus_ms bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_agg_user_date ON daily_aggregates (user_id, date DESC);

-- ---------------------------------------------------------------------------
-- User Preferences (app settings synced to cloud)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS user_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  idle_timeout_seconds integer NOT NULL DEFAULT 300,
  launch_at_login boolean NOT NULL DEFAULT true,
  show_tray boolean NOT NULL DEFAULT true,
  notifications_enabled boolean NOT NULL DEFAULT true,
  theme text NOT NULL DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
  focus_block_list jsonb NOT NULL DEFAULT '[]',
  custom_app_rules jsonb NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- RLS Policies for new tables
-- ---------------------------------------------------------------------------

ALTER TABLE app_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_aggregates ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own app_sessions" ON app_sessions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own app_events" ON app_events FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own app_rules" ON app_rules FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own study_sessions" ON study_sessions FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own daily_aggregates" ON daily_aggregates FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users manage own preferences" ON user_preferences FOR ALL USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Auto-create user preferences on signup
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, plan, created_at, updated_at)
  VALUES (NEW.id, 'free', now(), now())
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ---------------------------------------------------------------------------
-- Trigger: auto-update daily aggregates timestamp
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS update_daily_agg_timestamp ON daily_aggregates;
CREATE TRIGGER update_daily_agg_timestamp
  BEFORE UPDATE ON daily_aggregates
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

REVOKE ALL ON TABLE app_sessions, app_events, app_rules, study_sessions,
  daily_aggregates, user_preferences FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
