-- =========================================================================
-- Drift – FULL Database Schema (v1 + v2 combined)
-- Paste this entire file into Supabase SQL Editor and click RUN
-- =========================================================================

-- ---------------------------------------------------------------------------
-- V1: Core tables (browsing data)
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

-- ---------------------------------------------------------------------------
-- V2: Business tables (billing, AI, teams)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS user_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  plan text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'team')),
  stripe_customer_id text UNIQUE,
  stripe_subscription_id text,
  subscription_status text NOT NULL DEFAULT 'none',
  trial_ends_at timestamptz,
  cancel_at timestamptz,
  email_digest_enabled boolean NOT NULL DEFAULT true,
  onboarded_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_plan ON user_profiles (plan);
CREATE INDEX IF NOT EXISTS idx_profiles_stripe ON user_profiles (stripe_customer_id);

CREATE TABLE IF NOT EXISTS ai_coaching_history (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_data jsonb NOT NULL DEFAULT '{}',
  coaching_response jsonb NOT NULL DEFAULT '{}',
  tokens_input integer NOT NULL DEFAULT 0,
  tokens_output integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coaching_user_time ON ai_coaching_history (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS ai_classification_cache (
  domain text PRIMARY KEY,
  category text NOT NULL CHECK (category IN ('productive', 'neutral', 'distraction')),
  confidence real NOT NULL DEFAULT 0.5,
  reason text,
  classified_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days')
);

CREATE TABLE IF NOT EXISTS teams (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  settings jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS team_members (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_id bigint NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, user_id)
);

CREATE TABLE IF NOT EXISTS team_invites (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_id bigint NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  email text NOT NULL,
  invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days')
);

CREATE TABLE IF NOT EXISTS analytics_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS focus_sessions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  planned_duration_ms bigint NOT NULL,
  actual_duration_ms bigint,
  blocked_domains jsonb NOT NULL DEFAULT '[]',
  interruptions integer NOT NULL DEFAULT 0,
  completed boolean NOT NULL DEFAULT false
);

-- =========================================================================
-- Row Level Security
-- =========================================================================

ALTER TABLE browsing_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE browsing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE drift_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_coaching_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_classification_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;

-- V1 RLS policies
CREATE POLICY "Users read own sessions" ON browsing_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own sessions" ON browsing_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own sessions" ON browsing_sessions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own sessions" ON browsing_sessions FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users read own events" ON browsing_events FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own events" ON browsing_events FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own events" ON browsing_events FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own events" ON browsing_events FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users read own transitions" ON transitions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own transitions" ON transitions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own transitions" ON transitions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own transitions" ON transitions FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users read own drift_points" ON drift_points FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own drift_points" ON drift_points FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own drift_points" ON drift_points FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own drift_points" ON drift_points FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users read own history" ON session_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own history" ON session_history FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own history" ON session_history FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own history" ON session_history FOR DELETE USING (auth.uid() = user_id);

-- V2 RLS policies
CREATE POLICY "Users read own profile" ON user_profiles FOR SELECT USING (auth.uid() = user_id);
-- Profile and billing mutations go through the authenticated backend. Direct
-- client updates would let a user attempt to change protected plan fields.
CREATE POLICY "Users read own coaching" ON ai_coaching_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Team members read team" ON teams FOR SELECT USING (id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid()));
CREATE POLICY "Owners manage team" ON teams FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "Members read own team" ON team_members FOR SELECT USING (team_id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid()));
CREATE POLICY "Invitees read own invites" ON team_invites FOR SELECT USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));
CREATE POLICY "Users read own analytics" ON analytics_events FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users manage own focus" ON focus_sessions FOR ALL USING (auth.uid() = user_id);

-- =========================================================================
-- Triggers
-- =========================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, plan, created_at, updated_at)
  VALUES (NEW.id, 'free', now(), now())
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profile_timestamp ON user_profiles;
CREATE TRIGGER update_profile_timestamp
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- All product data is backend-only. The service_role used by the API retains
-- access; browser/desktop clients cannot bypass API authorization via PostgREST.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
