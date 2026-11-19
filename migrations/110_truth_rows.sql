
create or replace function truth_families(v uuid)
returns json
language sql security definer set search_path = public as $$
  select coalesce((select json_agg(row_to_json(f) order by f.days_left nulls last) from (
    select s.family, s.exam as label, s.schools, s.items, s.practised, s.verdict, s.message,
           (select min(c.sits_on) from exam_calendar c
             where c.student_id = v and c.sits_on >= (now() at time zone 'Australia/Melbourne')::date
               and (lower(c.exam) like '%' || lower(s.exam) || '%'
                    or (s.family = 'edutest' and lower(c.exam) like '%elms%'))) as exam_on,
           (select min(c.sits_on) from exam_calendar c
             where c.student_id = v and c.sits_on >= (now() at time zone 'Australia/Melbourne')::date
               and (lower(c.exam) like '%' || lower(s.exam) || '%'
                    or (s.family = 'edutest' and lower(c.exam) like '%elms%')))
             - (now() at time zone 'Australia/Melbourne')::date as days_left,
           (select count(*) from chapters ch where ch.source = any(
              array(select case when b.kind = 'olympiad' then 'book' else b.kind end
                    from exam_banks b where b.family = s.family))) as topics_all,
           (select count(*) from json_array_elements(topic_readiness(s.family)) t
             where (t->>'preparedness')::int >= 60) as topics_done,
           (select count(*) from json_array_elements(topic_readiness(s.family)) t
             where (t->>'preparedness')::int > 0) as topics_started,
           (select coalesce(json_agg(row_to_json(sc)), '[]'::json) from (
              select x->>'school' as school, x->>'calendar_name' as calendar_name,
                     x->>'sits_on' as sits_on, (x->>'sits_minutes')::int as sits_minutes,
                     (x->>'measured_minutes')::int as measured_minutes,
                     x->>'headline' as headline, x->'sections' as sections
              from json_array_elements(readiness_by_school()->'schools') x
              where x->>'exam' = s.exam) sc) as schools_list
    from v_exam_readiness s) f), '[]'::json);
$$;
grant execute on function truth_families(uuid) to authenticated;
-- ============================================================================
-- 105_truth.sql
-- ONE source of truth. Every number about the child — content, topics, scores,
-- accuracy, tests, readiness — is computed here and nowhere else. The child's
-- screens, the parent's screens, the child's coach and the parent's coach all
-- read this same function, so they cannot disagree.
-- Run after 104. Safe to re-run.
-- ============================================================================

-- ============================================================================
-- 105_truth.sql
-- ONE source of truth. Every number about the child — content, topics, scores,
-- accuracy, tests, readiness — is computed here and nowhere else. The child's
-- screens, the parent's screens, the child's coach and the parent's coach all
-- read this same function, so they cannot disagree.
-- Run after 104. Safe to re-run.
-- ============================================================================

create or replace function truth()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v uuid := coalesce(viewing_student(), auth.uid());
  v_today date := (now() at time zone 'Australia/Melbourne')::date;
  v_out json;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;

  select json_build_object(

    'as_of', now(),

    'student', json_build_object(
      'id', v,
      'name', (select name from profiles where student_id = v),
      'xp', coalesce((select xp from profiles where student_id = v), 0),
      'streak', coalesce((select streak_days from profiles where student_id = v), 0),
      'days_in', (v_today - coalesce((select start_date from profiles where student_id = v), v_today)) + 1,
      'first_day', not exists (select 1 from attempts where student_id = v)
    ),

    -- everything he has answered, and how well
    'attempts', json_build_object(
      'total', (select count(*) from attempts where student_id = v),
      'last_7', (select count(*) from attempts where student_id = v and created_at > now() - interval '7 days'),
      'correct_total', (select count(*) from attempts where student_id = v and ok),
      'accuracy_7', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                     from attempts where student_id = v and created_at > now() - interval '7 days'), 0),
      'accuracy_all', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                     from attempts where student_id = v), 0),
      'avg_seconds', coalesce((select round(avg(seconds)) from attempts
                     where student_id = v and seconds is not null and created_at > now() - interval '14 days'), 0)
    ),

    'sessions', json_build_object(
      'last_7', (select count(*) from sessions where student_id = v and created_at > now() - interval '7 days'),
      'total', (select count(*) from sessions where student_id = v),
      'last_day', (select max(day) from sessions where student_id = v)
    ),

    -- what is in the bank, per bank, counted once
    'content', json_build_object(
      'total', (select count(*) from problems),
      'banks', coalesce((select json_agg(row_to_json(b) order by b.exam) from (
        select x.exam, x.kind, x.family,
               (select count(*) from problems p where p.source = x.kind) as questions,
               (select count(*) from problems p where p.source = x.kind and p.paper_id is not null) as from_files,
               (select count(*) from problems p where p.source = x.kind and p.paper_id is null) as by_coach
        from exam_banks x) b), '[]'::json)
    ),

    -- per exam family: the paper, the topics, and where he is
    'families', coalesce((select json_agg(row_to_json(f) order by f.days_left nulls last) from (
      select s.family, s.exam as label, s.schools, s.items, s.practised, s.verdict, s.message,
             (select min(c.sits_on) from exam_calendar c
               where c.student_id = v and c.sits_on >= v_today
                 and (lower(c.exam) like '%' || lower(s.exam) || '%'
                      or (s.family = 'edutest' and lower(c.exam) like '%elms%'))) as exam_on,
             (select min(c.sits_on) from exam_calendar c
               where c.student_id = v and c.sits_on >= v_today
                 and (lower(c.exam) like '%' || lower(s.exam) || '%'
                      or (s.family = 'edutest' and lower(c.exam) like '%elms%'))) - v_today as days_left,
             (select count(*) from chapters ch where ch.source = any(
                array(select case when b.kind = 'olympiad' then 'book' else b.kind end
                      from exam_banks b where b.family = s.family))) as topics_all,
             (select count(*) from json_array_elements(topic_readiness(s.family)) t
               where (t->>'preparedness')::int >= 60) as topics_done,
             (select count(*) from json_array_elements(topic_readiness(s.family)) t
               where (t->>'preparedness')::int > 0) as topics_started,
             (select t2->'rows' from json_array_elements(timetable()) t2
               where lower(t2->>'label') = lower(s.exam)) as rows,
             (select (t2->>'behind')::int from json_array_elements(timetable()) t2
               where lower(t2->>'label') = lower(s.exam)) as behind,
             (select (t2->>'due_by_now')::int from json_array_elements(timetable()) t2
               where lower(t2->>'label') = lower(s.exam)) as due_by_now,
             (select coalesce(json_agg(row_to_json(sc)), '[]'::json) from (
                select x->>'school' as school, x->>'calendar_name' as calendar_name,
                       x->>'sits_on' as sits_on, (x->>'sits_minutes')::int as sits_minutes,
                       (x->>'measured_minutes')::int as measured_minutes,
                       x->>'headline' as headline, x->'sections' as sections
                from json_array_elements(readiness_by_school()->'schools') x
                where x->>'exam' = s.exam) sc) as schools_list
      from v_exam_readiness s) f), '[]'::json),

    -- the papers, and whether one is due
    'tests', json_build_object(
      'count', (select count(*) from exam_mocks where student_id = v),
      'last', coalesce((select json_agg(row_to_json(x) order by x.taken_at desc) from (
        select kind, score, total, pct, taken_at from exam_mocks
        where student_id = v order by taken_at desc limit 5) x), '[]'::json),
      'due', mock_due(v)
    ),

    'progress', progress_dashboard(),
    'reviews', due_reviews(),
    'sitting', sitting_plan(),
    'board', formula_board_view(),
    'uploads', papers_to_read(),
    'budget', 150,

    'weak', coalesce((select json_agg(json_build_object('technique', technique, 'open', open_items))
                      from v_weak_techniques where student_id = v limit 5), '[]'::json),

    'tough_topics', tough_topics(6),
    'freshness', family_freshness(),
    'journey', (select json_build_object(
        'today', v_today,
        'start', coalesce((select start_date from profiles where student_id = v), v_today),
        'end', (select max(c.sits_on) from exam_calendar c where c.student_id = v),
        'topics_total', (select coalesce(sum((f->>'topics_all')::int), 0) from json_array_elements(truth_families(v)) f),
        'topics_done', (select coalesce(sum((f->>'topics_done')::int), 0) from json_array_elements(truth_families(v)) f),
        'topics_started', (select coalesce(sum((f->>'topics_started')::int), 0) from json_array_elements(truth_families(v)) f),
        'exams', (select count(*) from json_array_elements(truth_families(v))),
        'questions', (select count(*) from attempts where student_id = v),
        'accuracy', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                      from attempts where student_id = v), 0),
        'streak', coalesce((select streak_days from profiles where student_id = v), 0)
      )),
    'specs', exam_specs(),
    'topup_needed', topup_needed(),
    'whats_new', coalesce((select json_object_agg(f.family, whats_new(f.family)) from (
        select distinct b.family from exam_banks b where b.family is not null) f), '{}'::json),
    'child', child_work_status(),
    'accounts', case when is_parent() then list_accounts() else null end,
    'chat', coalesce((select json_agg(row_to_json(m) order by m.created_at) from (
        select role, body, created_at from chat_messages
        where student_id = v and coalesce(thread,'child') = 'child'
        order by created_at desc limit 200) m), '[]'::json),

    'parent_chat', coalesce((select json_agg(row_to_json(m) order by m.created_at) from (
        select role, body, created_at from chat_messages
        where student_id = v and thread = 'parent'
        order by created_at desc limit 200) m), '[]'::json),

    'papers', coalesce((select json_agg(row_to_json(p) order by p.id desc) from (
        select id, title, exam, pages, questions, created_at, strand_hint from papers
        where student_id = v order by id desc limit 30) p), '[]'::json)
  ) into v_out;

  return v_out;
end $$;

grant execute on function truth() to authenticated;

-- the parent's context is the truth, plus the few things only a parent screen needs
create or replace function parent_context()
returns json
language plpgsql security definer set search_path = public as $$
declare v uuid := coalesce(viewing_student(), auth.uid());
begin
  return truth() || json_build_object(
    'student_id', v,
    'student', (select name from profiles where student_id = v),
    'xp', coalesce((select xp from profiles where student_id = v), 0),
    'streak', coalesce((select streak_days from profiles where student_id = v), 0),
    'attempts_total', (select count(*) from attempts where student_id = v),
    'attempts_7d', (select count(*) from attempts where student_id = v
                     and created_at > now() - interval '7 days'),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                     from attempts where student_id = v and created_at > now() - interval '7 days'), 0),
    'sessions_7d', (select count(*) from sessions where student_id = v
                     and created_at > now() - interval '7 days'),
    'readiness', readiness_by_school(),
    'banks', (truth()->'content'->'banks'),
    'weak', (truth()->'weak'),
    'recent_tests', (truth()->'tests'->'last'),
    'tough', (truth()->'tough_topics')
  );
end $$;
grant execute on function parent_context() to authenticated;
