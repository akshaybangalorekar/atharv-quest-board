-- ============================================================================
-- 063_exam_dates.sql
-- The parent table gets the date each exam is sat, and a way to set it. A date
-- that the school has not published is marked "expected"; the moment a parent
-- types the real one it becomes "confirmed".
-- Run after 062. Safe to re-run.
-- ============================================================================

create or replace function set_exam_date(p_exam text, p_on date, p_confirmed boolean default true)
returns json
language plpgsql security definer set search_path = public as $$
declare v uuid := viewing_student();
begin
  if not is_parent() then
    raise exception 'only a parent can change an exam date' using errcode = '42501';
  end if;
  if v is null then raise exception 'no student linked to this login' using errcode = '28000'; end if;
  if p_on is null then raise exception 'give a date' using errcode = '22023'; end if;

  update exam_calendar
     set sits_on = p_on,
         date_status = case when p_confirmed then 'confirmed' else 'expected' end
   where student_id = v and exam = p_exam;

  if not found then
    insert into exam_calendar (student_id, exam, sits_on, date_status, target, note)
    values (v, p_exam, p_on, case when p_confirmed then 'confirmed' else 'expected' end,
            null, 'Date set by a parent.');
  end if;

  return json_build_object('exam', p_exam, 'on', p_on, 'status', case when p_confirmed then 'confirmed' else 'expected' end);
end $$;

grant execute on function set_exam_date(text, date, boolean) to authenticated;

create or replace function readiness_by_school()
returns json
language plpgsql security definer set search_path = public as $$
declare
  -- a parent sees the child's numbers and the child's calendar, not their own
  v uuid := coalesce(viewing_student(), auth.uid());
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_out json;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  with sections as (
    select * from (values
      ('Verbal reasoning',      'ver',  30, 1),
      ('Numerical reasoning',   'nr',   30, 2),
      ('Reading comprehension', 'rc',   30, 3),
      ('Mathematics',           'math', 30, 4),
      ('Written expression',    'we',   15, 5)
    ) as t(part, code, minutes, seq)
  ),
  schools as (
    select * from (values
      ('Kilvington Grammar',           'Edutest',   'Edutest numerical reasoning', 'ver',  null),
      ('Kilvington Grammar',           'Edutest',   'Edutest numerical reasoning', 'nr',   'edutest'),
      ('Kilvington Grammar',           'Edutest',   'Edutest numerical reasoning', 'rc',   null),
      ('Kilvington Grammar',           'Edutest',   'Edutest numerical reasoning', 'math', 'elms'),
      ('Kilvington Grammar',           'Edutest',   'Edutest numerical reasoning', 'we',   null),
      ('McKinnon Secondary (ELMS)',    'Edutest',   'ELMS',                        'math', 'elms'),
      ('Camberwell Grammar',           'AAS',       'AAS numerical reasoning',     'math', 'aas'),
      ('The book · APSMO Division J',  'Olympiad',  'APSMO Division J',            'math', 'book'),
      ('ICAS Mathematics',             'ICAS',      'ICAS Maths',                  'math', 'icas'),
      ('Australian Maths Competition', 'AMC',       'AMC Upper Primary',           'math', 'amc')
    ) as s(school, exam, cal_name, code, kind)
  ),
  detail as (
    select s.school, s.exam, s.cal_name, sec.part, sec.minutes, s.kind, sec.seq,
           c.sits_on, c.date_status,
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
    left join exam_calendar c on c.student_id = v and c.exam = s.cal_name
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
           max(cal_name) as calendar_name,
           max(sits_on) as sits_on,
           max(date_status) as date_status,
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
