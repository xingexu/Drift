-- =========================================================================
-- Drift – Supabase Database Schema
-- Run this in the Supabase SQL Editor to set up all tables
-- =========================================================================

-- ---------------------------------------------------------------------------
-- Table: browsing_sessions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS browsing_sessions (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_time bigint NOT NULL,
  end_time bigint NOT NULL,
  total_duration_ms bigint NOT NULL,
  entry_event_id text NOT NULL,
  exit_event_id text NOT NULL,
  drift_score real NOT NULL DEFAULT 0,
  summary_label text,
  stats jsonb NOT NULL DEFAULT '{}',
  intent jsonb,
  synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_time ON browsing_sessions (user_id, start_time DESC);

-- ---------------------------------------------------------------------------
-- Table: browsing_events
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS browsing_events (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id text REFERENCES browsing_sessions(id) ON DELETE CASCADE,
  tab_id integer NOT NULL DEFAULT 0,
  window_id integer NOT NULL DEFAULT 0,
  raw_url text NOT NULL,
  normalized_url text NOT NULL,
  domain text NOT NULL,
  path text,
  title text,
  start_time bigint NOT NULL,
  end_time bigint NOT NULL,
  duration_ms bigint NOT NULL,
  previous_event_id text,
  transition_type text,
  category text,
  classification_source text,
  classification_reason text,
  drift boolean NOT NULL DEFAULT false,
  drift_reasons jsonb NOT NULL DEFAULT '[]',
  synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_user_time ON browsing_events (user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_events_session ON browsing_events (session_id);

-- ---------------------------------------------------------------------------
-- Table: transitions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transitions (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id text NOT NULL REFERENCES browsing_sessions(id) ON DELETE CASCADE,
  source_event_id text NOT NULL,
  target_event_id text NOT NULL,
  source_domain text NOT NULL,
  target_domain text NOT NULL,
  source_normalized_url text,
  target_normalized_url text,
  time_gap_ms bigint,
  is_category_shift boolean NOT NULL DEFAULT false,
  from_category text,
  to_category text,
  synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transitions_session ON transitions (user_id, session_id);

-- ---------------------------------------------------------------------------
-- Table: drift_points
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS drift_points (
  id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id text NOT NULL REFERENCES browsing_sessions(id) ON DELETE CASCADE,
  event_id text,
  transition_id text,
  "timestamp" bigint NOT NULL,
  reason text NOT NULL,
  trigger text NOT NULL,
  synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_drift_points_session ON drift_points (user_id, session_id);

-- ---------------------------------------------------------------------------
-- Table: session_history
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS session_history (
  session_id text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  start_time bigint NOT NULL,
  end_time bigint NOT NULL,
  total_active_time_ms bigint NOT NULL,
  productive_time_ms bigint NOT NULL DEFAULT 0,
  neutral_time_ms bigint NOT NULL DEFAULT 0,
  distraction_time_ms bigint NOT NULL DEFAULT 0,
  drift_score real NOT NULL DEFAULT 0,
  drift_point_count integer NOT NULL DEFAULT 0,
  summary_label text,
  entry_domain text,
  exit_domain text,
  top_domains jsonb NOT NULL DEFAULT '[]',
  event_count integer NOT NULL DEFAULT 0,
  synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_history_user_time ON session_history (user_id, start_time DESC);

-- =========================================================================
-- Row Level Security
-- =========================================================================

ALTER TABLE browsing_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE browsing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE drift_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_history ENABLE ROW LEVEL SECURITY;

-- browsing_sessions
CREATE POLICY "Users read own sessions" ON browsing_sessions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own sessions" ON browsing_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own sessions" ON browsing_sessions
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own sessions" ON browsing_sessions
  FOR DELETE USING (auth.uid() = user_id);

-- browsing_events
CREATE POLICY "Users read own events" ON browsing_events
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own events" ON browsing_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own events" ON browsing_events
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own events" ON browsing_events
  FOR DELETE USING (auth.uid() = user_id);

-- transitions
CREATE POLICY "Users read own transitions" ON transitions
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own transitions" ON transitions
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own transitions" ON transitions
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own transitions" ON transitions
  FOR DELETE USING (auth.uid() = user_id);

-- drift_points
CREATE POLICY "Users read own drift_points" ON drift_points
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own drift_points" ON drift_points
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own drift_points" ON drift_points
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own drift_points" ON drift_points
  FOR DELETE USING (auth.uid() = user_id);

-- session_history
CREATE POLICY "Users read own history" ON session_history
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own history" ON session_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own history" ON session_history
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own history" ON session_history
  FOR DELETE USING (auth.uid() = user_id);
