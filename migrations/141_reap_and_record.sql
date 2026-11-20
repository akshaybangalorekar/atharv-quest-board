-- 141: one record_usage signature, and a reaper for runs whose request died
drop function if exists record_usage(text, int, int);
create or replace function reap_stuck_jobs()
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update jobs set status = 'failed', finished_at = now(),
         error = coalesce(error, 'the run stopped without finishing')
   where status = 'running' and started_at < now() - interval '30 minutes';
  get diagnostics n = row_count;
  return n;
end $$;
grant execute on function reap_stuck_jobs() to authenticated;
