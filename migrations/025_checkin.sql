-- ============================================================================
-- 025_checkin.sql
-- The coach asks what he has been doing and how confident he feels, and keeps
-- the answer with the rest of his history.
-- Run after 024. Safe to re-run.
-- ============================================================================

alter table self_reports add column if not exists confidence int;      -- 1 to 5, his own words
alter table self_reports add column if not exists topics text[];       -- what he named

create or replace function log_checkin(
  p_note text default null,
  p_minutes int default 0,
  p_confidence int default null,
  p_topics text[] default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_day date := (now() at time zone 'Australia/Melbourne')::date;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;
  insert into self_reports (student_id, day, minutes, note, confidence, topics)
  values (v, v_day, coalesce(p_minutes,0), p_note, p_confidence, p_topics);
  return json_build_object('day', v_day, 'confidence', p_confidence);
end $$;

-- the coach sees the latest check-in alongside everything else
create or replace function last_checkin()
returns json
language sql security definer set search_path = public as $$
  select coalesce((select json_build_object('day',day,'note',note,'minutes',minutes,
                          'confidence',confidence,'topics',topics)
                   from self_reports where student_id = auth.uid()
                   order by created_at desc limit 1), '{}'::json);
$$;
