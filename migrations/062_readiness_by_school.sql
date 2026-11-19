-- ============================================================================
-- 062_readiness_by_school.sql
-- Edutest is one paper family, but the two schools sit different amounts of it:
--   Kilvington  — the whole paper: verbal reasoning, numerical reasoning,
--                 reading comprehension, mathematics, written expression.
--   McKinnon    — mathematics only (ELMS).
-- So readiness is reported per school, over the sections that school actually
-- sits, and a section this app has no questions for is marked as not measured
-- rather than quietly counted as zero.
-- Run after 061. Safe to re-run.
-- ============================================================================

create or replace function readiness_by_school()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := auth.uid();
  v_out json;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  with sections as (
    select * from (values
      ('Verbal reasoning',      'ver',  30, 1),
      ('Numerical reasoning',   'nr',   30, 2),
      ('Reading comprehension', 'rc',   30, 3),
      ('Mathematics',           'math',   30, 4),
      ('Mathematics',           'math45', 45, 4),   -- AAS: each paper is 40 to 50 minutes
      ('Mathematics',           'math30', 30, 4),   -- APSMO Division J: 5 questions in 30 minutes
      ('Mathematics',           'math60', 60, 4),   -- ICAS Paper D and AMC Upper Primary: 60 minutes
      ('Written expression',    'we',   15, 5)
    ) as t(part, code, minutes, seq)
  ),
  -- which sections each school sits, and which bank of questions answers for it
  schools as (
    select * from (values
      ('Kilvington Grammar',           'Edutest',   'ver',  null),
      ('Kilvington Grammar',           'Edutest',   'nr',   'edutest'),
      ('Kilvington Grammar',           'Edutest',   'rc',   null),
      ('Kilvington Grammar',           'Edutest',   'math', 'elms'),
      ('Kilvington Grammar',           'Edutest',   'we',   null),
      ('McKinnon Secondary (ELMS)',    'Edutest',   'math', 'elms'),
      ('Camberwell Grammar',           'AAS',       'math45', 'aas'),
      ('The book · APSMO Division J',  'Olympiad',  'math30', 'book'),
      ('ICAS Mathematics',             'ICAS',      'math60', 'icas'),
      ('Australian Maths Competition', 'AMC',       'math60', 'amc')
    ) as s(school, exam, code, kind)
  ),
  detail as (
    select s.school, s.exam, sec.part, sec.minutes, s.kind, sec.seq,
           (s.kind is not null) as covered,
           coalesce((select count(*) from problems p where s.kind is not null and p.source = s.kind), 0) as loaded,
           coalesce((select count(*) from attempts a join problems p
                       on p.chapter = a.chapter and p.idx = a.idx
                     where s.kind is not null and a.student_id = v and p.source = s.kind), 0) as tried,
           coalesce((select count(*) from attempts a join problems p
                       on p.chapter = a.chapter and p.idx = a.idx
                     where s.kind is not null and a.student_id = v and p.source = s.kind and a.ok), 0) as correct
    from schools s
    join sections sec on sec.code = s.code
  ),
  judged as (
    select *,
      case when not covered then 'not measured here'
           when loaded = 0 then 'no questions yet'
           when tried < 15 then 'too early to say'
           when tried < 30 then 'some evidence'
           when round(100.0 * correct / tried) >= 80 then 'solid'
           when round(100.0 * correct / tried) >= 60 then 'coming along'
           else 'needs work' end as verdict
    from detail
  )
  select coalesce(json_agg(row_to_json(g) order by g.exam, g.school), '[]'::json)
    into v_out
  from (
    select school, exam,
           sum(minutes) as sits_minutes,
           sum(minutes) filter (where covered) as measured_minutes,
           case
             when bool_or(verdict = 'needs work') then 'needs work'
             when bool_and(verdict = 'not measured here') then 'nothing measured yet'
             when bool_or(verdict = 'not measured here')
                  and bool_or(verdict in ('solid','coming along')) then 'partly measured'
             when bool_and(verdict in ('solid','coming along')) then 'solid'
             when bool_or(verdict in ('solid','coming along','some evidence')) then 'partly measured'
             else 'too early to say'
           end as headline,
           json_agg(json_build_object(
             'part', part, 'minutes', minutes, 'covered', covered, 'loaded', loaded,
             'tried', tried, 'correct', correct,
             'accuracy', case when tried = 0 then null else round(100.0 * correct / tried) end,
             'verdict', verdict) order by seq) as sections
    from judged
    group by school, exam
  ) g;

  return json_build_object('schools', v_out);
end $$;

grant execute on function readiness_by_school() to authenticated;
