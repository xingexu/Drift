-- Apply once to an existing Drift Supabase project after the schema files.
-- New installations already include these protections in schema-full.sql and
-- schema-v3-desktop.sql.

BEGIN;

ALTER TABLE IF EXISTS public.ai_classification_cache ENABLE ROW LEVEL SECURITY;

-- Direct profile updates could include billing/plan columns. All mutations
-- must pass through the backend's authenticated, field-restricted routes.
DROP POLICY IF EXISTS "Users update own profile" ON public.user_profiles;

-- Drift clients are local-only and never query PostgREST directly. Removing
-- anon/authenticated privileges prevents a leaked public key from bypassing
-- API validation. The service_role used by the backend is unaffected.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;

ALTER FUNCTION public.handle_new_user() SET search_path = '';
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

COMMIT;
