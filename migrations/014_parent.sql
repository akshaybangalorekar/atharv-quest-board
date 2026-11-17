-- ============================================================================
-- 014_parent.sql
-- What a parent needs: to see how the child is doing (not their own blank row),
-- to add questions for any exam, and to be told what data is still missing.
-- Run after 013. Safe to re-run.
-- ============================================================================

create or replace function is_parent()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from guardians where parent_id = auth.uid());
$$;

-- which student this login is looking at: his own row, or his child's
create or replace function viewing_student()
returns uuid language sql stable security definer set search_path = public as $$
  select coalesce(
    (select student_id from profiles where student_id = auth.uid()),
    (select student_id from guardians where parent_id = auth.uid() limit 1)
  );
$$;

-- ---- readiness, computed for a named student -----------------------------
create or replace function exam_readiness_for(p_student uuid default null)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := coalesce(p_student, viewing_student());
  v_out json;
begin
  if v_student is null then raise exception 'no student' using errcode = '28000'; end if;
  if not (v_student = auth.uid() or is_guardian(v_student)) then
    raise exception 'not your child' using errcode = '42501';
  end if;

  with per_q as (
    select chapter, idx, count(*) as tries, count(*) filter (where ok) as ok_count
    from attempts where student_id = v_student group by chapter, idx
  ),
  open_w as (select chapter, idx from weak_queue where student_id = v_student)
  select coalesce(json_agg(json_build_object(
      'exam', m.exam, 'items', agg.items, 'practised', agg.practised, 'mastered', agg.mastered,
      'pct_mastered', agg.pct, 'verdict', agg.verdict, 'message', agg.message) order by m.exam), '[]'::json)
  into v_out
  from (select distinct exam from exam_map) m
  join lateral (
    select count(*) as items,
           count(pq.tries) as practised,
           count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) as mastered,
           case when count(*) = 0 then 0
                else round(100.0 * count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) / count(*)) end as pct,
           case when count(*) = 0 then 'no_content'
                when count(*) < 30 then 'thin'
                when count(pq.tries) < 0.4 * count(*) then 'too_early'
                when round(100.0 * count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) / count(*)) >= 80 then 'ready'
                else 'in_progress' end as verdict,
           case when count(*) = 0 then 'No questions uploaded for this exam yet.'
                when count(*) < 30 then 'Only ' || count(*) || ' questions uploaded. More content is needed before this can be judged.'
                when count(pq.tries) < 0.4 * count(*) then count(pq.tries) || ' of ' || count(*) || ' practised so far. Too early to say — keep going.'
                when round(100.0 * count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) / count(*)) >= 80
                  then count(*) || ' questions uploaded, ' || count(pq.tries) || ' practised, '
                       || count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) || ' mastered. The content is enough.'
                else count(*) || ' questions uploaded, ' || count(pq.tries) || ' practised, '
                       || count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) || ' mastered. More practice needed before this is judged.' end as message
    from exam_map em
    left join per_q pq on pq.chapter = em.chapter and pq.idx = em.idx
    left join open_w w on w.chapter = em.chapter and w.idx = em.idx
    where em.exam = m.exam
  ) agg on true;
  return v_out;
end $$;

-- ---- add questions to any exam ------------------------------------------
-- p_rows is a JSON array of {"q": "prompt", "a": "answer"}.
-- The answer becomes the key; leave it blank to mark that question by hand.
create or replace function add_questions(p_exam text, p_strand text, p_rows jsonb)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_bank exam_banks;
  v_chapter int;
  v_title text := p_exam || ' · ' || coalesce(nullif(p_strand,''), 'General');
  v_idx int;
  v_n int := 0;
  r jsonb;
begin
  if not is_parent() then
    raise exception 'only a parent can add questions' using errcode = '42501';
  end if;

  select * into v_bank from exam_banks where exam = p_exam;
  if not found then
    raise exception 'unknown exam %, register it in exam_banks first', p_exam;
  end if;

  select n into v_chapter from chapters where title = v_title;
  if v_chapter is null then
    select coalesce(max(n), v_bank.chapter_from - 1) + 1 into v_chapter
    from chapters where n between v_bank.chapter_from and v_bank.chapter_to;
    insert into chapters (n, title, pages, examples, practice, tier, source)
    values (v_chapter, v_title, null, 0, 0, 1, v_bank.kind);
  end if;

  select coalesce(max(idx), 0) into v_idx from problems where chapter = v_chapter;

  for r in select * from jsonb_array_elements(p_rows) loop
    if coalesce(trim(r->>'q'), '') = '' then continue; end if;
    v_idx := v_idx + 1; v_n := v_n + 1;
    insert into problems (chapter, idx, prompt, difficulty, technique_tags, source)
    values (v_chapter, v_idx, trim(r->>'q'), coalesce((r->>'d')::int, 2),
            array[coalesce(nullif(p_strand,''), 'General')], v_bank.kind);

    insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode)
    values (v_chapter, v_idx, coalesce(nullif(trim(r->>'a'),''), 'Marked by hand.'),
            coalesce(nullif(trim(r->>'a'),''), 'Marked by hand.'),
            nullif(trim(r->>'a'),''),
            case when coalesce(trim(r->>'a'),'') = '' then 'manual' else 'auto' end);

    insert into exam_map (exam, chapter, idx) values (p_exam, v_chapter, v_idx)
    on conflict do nothing;
  end loop;

  update chapters set practice = (select count(*) from problems where chapter = v_chapter) where n = v_chapter;

  return json_build_object('exam', p_exam, 'strand', v_title, 'chapter', v_chapter, 'added', v_n);
end $$;

-- ---- everything the parent chat needs -----------------------------------
create or replace function parent_context()
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := viewing_student();
  v_out json;
begin
  if v_student is null then raise exception 'no student' using errcode = '28000'; end if;
  if not (v_student = auth.uid() or is_guardian(v_student)) then
    raise exception 'not your child' using errcode = '42501';
  end if;

  select json_build_object(
    'student', (select name from profiles where student_id = v_student),
    'xp', coalesce((select xp from profiles where student_id = v_student),0),
    'streak', coalesce((select streak_days from profiles where student_id = v_student),0),
    'readiness', exam_readiness_for(v_student),
    'banks', coalesce((select json_agg(json_build_object('exam',exam,'kind',kind,'from',chapter_from,'to',chapter_to)) from exam_banks), '[]'::json),
    'weak', coalesce((select json_agg(json_build_object('technique',technique,'open',open_items,'misses',misses))
                      from v_weak_techniques where student_id = v_student limit 5), '[]'::json),
    'recent_tests', coalesce((select json_agg(json_build_object('kind',kind,'pct',pct,'score',score,'total',total,'taken_at',taken_at) order by taken_at desc)
                      from exam_mocks where student_id = v_student limit 5), '[]'::json),
    'chapters', coalesce((select json_agg(json_build_object('chapter',chapter,'quiz_best',quiz_best,'weak',weak))
                      from chapter_progress where student_id = v_student), '[]'::json),
    'attempts_total', (select count(*) from attempts where student_id = v_student),
    'attempts_7d', (select count(*) from attempts where student_id = v_student and created_at > now() - interval '7 days'),
    'accuracy_7d', coalesce((select round(100.0 * count(*) filter (where ok) / greatest(count(*),1))
                      from attempts where student_id = v_student and created_at > now() - interval '7 days'), 0),
    'sessions_7d', (select count(*) from sessions where student_id = v_student and day > current_date - 7)
  ) into v_out;
  return v_out;
end $$;
