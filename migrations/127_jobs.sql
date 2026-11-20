-- 127_jobs.sql — every background run leaves a row, so "it ran" is a fact, not a claim.
create table if not exists jobs (
  id bigserial primary key, student_id uuid, kind text not null,
  status text not null default 'running', detail jsonb not null default '{}'::json,
  error text, started_at timestamptz not null default now(), finished_at timestamptz);
create index if not exists jobs_recent on jobs (student_id, started_at desc);

create or replace function start_job(p_kind text) returns bigint
language plpgsql security definer set search_path = public as $$
declare v uuid := coalesce(viewing_student(), auth.uid()); v_id bigint;
begin insert into jobs (student_id, kind) values (v, p_kind) returning id into v_id; return v_id; end $$;

create or replace function finish_job(p_id bigint, p_ok boolean, p_detail jsonb default '{}'::json, p_error text default null)
returns void language plpgsql security definer set search_path = public as $$
begin update jobs set status = case when p_ok then 'done' else 'failed' end,
  detail = coalesce(p_detail,'{}'::jsonb), error = p_error, finished_at = now() where id = p_id; end $$;

create or replace function recent_jobs(p_limit int default 6) returns json
language sql security definer set search_path = public as $$
  select coalesce((select json_agg(row_to_json(j) order by j.started_at desc) from (
    select id, kind, status, detail, error, started_at, finished_at from jobs
    where student_id = coalesce(viewing_student(), auth.uid())
    order by started_at desc limit greatest(1, coalesce(p_limit,6))) j), '[]'::json); $$;

grant execute on function start_job(text) to authenticated;
grant execute on function finish_job(bigint, boolean, jsonb, text) to authenticated;
grant execute on function recent_jobs(int) to authenticated;
