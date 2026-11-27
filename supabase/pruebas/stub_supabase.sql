-- Imitación mínima de lo que Supabase ya trae
do $$ begin create role anon nologin; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated nologin; exception when duplicate_object then null; end $$;
do $$ begin create role service_role nologin bypassrls; exception when duplicate_object then null; end $$;
create schema auth;
create table auth.users (id uuid primary key default gen_random_uuid(), email text unique, raw_user_meta_data jsonb default '{}');
create function auth.uid() returns uuid language sql stable as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::json->>'sub','')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean);
create table storage.objects (id uuid default gen_random_uuid(), bucket_id text, name text, owner uuid);
alter table storage.objects enable row level security;
create publication supabase_realtime;
