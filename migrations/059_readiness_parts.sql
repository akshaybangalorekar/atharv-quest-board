-- ============================================================================
-- 059_readiness_parts.sql
-- Readiness, per part of the paper, instead of one number per school.
--
-- Edutest is five sections: Verbal Reasoning, Numerical Reasoning, Reading
-- Comprehension, Mathematics (30 minutes each) and Written Expression
-- (15 minutes). McKinnon's ELMS is mathematics only. One number cannot describe
-- both, so the app now reports each part, and says plainly which parts this app
-- has no questions for.
-- Run after 058. Safe to re-run.
-- ============================================================================

create or replace function readiness_parts(p_family text)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_out json;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  with parts as (
    select * from (values
      ('Numerical reasoning', 'edutest',   30, 'measured'),
      ('Mathematics',         'elms',      30, 'measured'),
      ('Verbal reasoning',    null,        30, 'not covered'),
      ('Reading comprehension', null,      30, 'not covered'),
      ('Written expression',  null,        15, 'not covered')
    ) as t(part, kind, minutes, coverage)
  ),
  stats as (
    select pa.part, pa.minutes, pa.coverage,
           coalesce((select count(*) from problems p
                     where pa.kind is not null and p.source = pa.kind), 0) as loaded,
           coalesce((select count(*) from attempts a join problems p
                       on p.chapter = a.chapter and p.idx = a.idx
                     where pa.kind is not null and a.student_id = v and p.source = pa.kind), 0) as practised,
           coalesce((select count(*) from attempts a join problems p
                       on p.chapter = a.chapter and p.idx = a.idx
                     where pa.kind is not null and a.student_id = v and p.source = pa.kind and a.ok), 0) as correct
    from parts pa
  )
  select coalesce(json_agg(json_build_object(
           'part', part, 'minutes', minutes, 'coverage', coverage,
           'loaded', loaded, 'practised', practised, 'right', correct,
           'accuracy', case when practised = 0 then null else round(100.0 * correct / practised) end,
           'verdict', case
             when coverage = 'not covered' then 'not measured here'
             when loaded = 0 then 'no questions yet'
             when practised < 15 then 'too early to say'
             when practised < 30 then 'some evidence'
             when round(100.0 * correct / practised) >= 80 then 'solid'
             when round(100.0 * correct / practised) >= 60 then 'coming along'
             else 'needs work' end
         ) order by minutes desc), '[]'::json)
    into v_out
  from stats;

  return json_build_object(
    'family', p_family,
    'parts', v_out,
    'maths_minutes', 60,
    'total_minutes', 135,
    'note', case when p_family = 'edutest'
      then 'Kilvington sits the whole paper: maths is 60 of 135 minutes. McKinnon''s ELMS is the mathematics part only.'
      else '' end
  );
end $$;

grant execute on function readiness_parts(text) to authenticated;
