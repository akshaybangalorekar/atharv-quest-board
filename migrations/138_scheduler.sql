-- 138_scheduler.sql — pg_net drains the queue every minute; no person needed.
create table if not exists app_config (key text primary key, value text not null);
insert into app_config (key, value) values ('drain_token', encode(gen_random_bytes(24),'hex'))
on conflict (key) do nothing;
revoke all on app_config from public, anon, authenticated;

create or replace function drain_token() returns text
language sql security definer set search_path = public as $$
  select value from app_config where key = 'drain_token'; $$;
revoke all on function drain_token() from public, anon, authenticated;

create or replace function students_with_queued() returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(distinct student_id), '[]'::json)
  from jobs where status = 'queued' and (next_try_at is null or next_try_at <= now()); $$;
revoke all on function students_with_queued() from public, anon, authenticated;

select cron.unschedule('quest-drain') where exists (select 1 from cron.job where jobname = 'quest-drain');
select cron.schedule('quest-drain', '* * * * *', $$
  select net.http_post(
    url := 'https://qjynqcbhyctisptciblp.supabase.co/functions/v1/cron-jobs',
    headers := jsonb_build_object('Content-Type','application/json'),
    body := jsonb_build_object('token', (select value from app_config where key = 'drain_token')),
    timeout_milliseconds := 120000);
$$);
