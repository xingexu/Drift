-- =========================================================================
-- Drift v2 – Extended Business Schema
-- Run this AFTER the original schema.sql
-- Adds: user profiles, subscriptions, AI coaching, teams, analytics
-- =========================================================================

-- ---------------------------------------------------------------------------
-- Table: user_profiles (billing, plan, preferences)
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
CREATE INDEX IF NOT EXISTS idx_profiles_sub_status ON user_profiles (subscription_status);

-- ---------------------------------------------------------------------------
-- Table: ai_coaching_history
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- Table: ai_classification_cache (reduces API calls)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_classification_cache (
  domain text PRIMARY KEY,
  category text NOT NULL CHECK (category IN ('productive', 'neutral', 'distraction')),
  confidence real NOT NULL DEFAULT 0.5,
  reason text,
  classified_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '30 days')
);

CREATE INDEX IF NOT EXISTS idx_classification_expires ON ai_classification_cache (expires_at);

-- ---------------------------------------------------------------------------
-- Table: teams
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teams (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  settings jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teams_owner ON teams (owner_id);

-- ---------------------------------------------------------------------------
-- Table: team_members
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS team_members (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_id bigint NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_team_members_team ON team_members (team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON team_members (user_id);

-- ---------------------------------------------------------------------------
-- Table: team_invites
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS team_invites (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_id bigint NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  email text NOT NULL,
  invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days')
);

CREATE INDEX IF NOT EXISTS idx_invites_email ON team_invites (email);
CREATE INDEX IF NOT EXISTS idx_invites_team ON team_invites (team_id);

-- ---------------------------------------------------------------------------
-- Table: analytics_events (aggregated, privacy-preserving)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_analytics_user_time ON analytics_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_type ON analytics_events (event_type, created_at DESC);

-- ---------------------------------------------------------------------------
-- Table: focus_sessions (Focus Mode — website blocking)
-- ---------------------------------------------------------------------------
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

CREATE INDEX IF NOT EXISTS idx_focus_user_time ON focus_sessions (user_id, started_at DESC);

-- =========================================================================
-- Row Level Security for new tables
-- =========================================================================

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_coaching_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;

-- user_profiles
CREATE POLICY "Users read own profile" ON user_profiles
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users update own profile" ON user_profiles
  FOR UPDATE USING (auth.uid() = user_id);

-- ai_coaching_history
CREATE POLICY "Users read own coaching" ON ai_coaching_history
  FOR SELECT USING (auth.uid() = user_id);

-- teams (members can read)
CREATE POLICY "Team members read team" ON teams
  FOR SELECT USING (
    id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid())
  );
CREATE POLICY "Owners manage team" ON teams
  FOR ALL USING (owner_id = auth.uid());

-- team_members
CREATE POLICY "Members read own team" ON team_members
  FOR SELECT USING (
    team_id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid())
  );

-- team_invites
CREATE POLICY "Invitees read own invites" ON team_invites
  FOR SELECT USING (email = (SELECT email FROM auth.users WHERE id = auth.uid()));

-- analytics_events
CREATE POLICY "Users read own analytics" ON analytics_events
  FOR SELECT USING (auth.uid() = user_id);

-- focus_sessions
CREATE POLICY "Users manage own focus" ON focus_sessions
  FOR ALL USING (auth.uid() = user_id);

-- =========================================================================
-- Functions & Triggers
-- =========================================================================

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id, plan, created_at, updated_at)
  VALUES (NEW.id, 'free', now(), now())
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-update updated_at on profile changes
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
