-- ============================================================================
-- 018_dedupe_solve.sql
-- No duplicate questions, room for a drawn diagram, and a record of who wrote
-- an answer (the book, a parent, or the model).
-- Run after 017. Safe to re-run.
-- ============================================================================

-- ---- no duplicates inside a chapter -------------------------------------
create unique index if not exists problems_prompt_key
  on problems (chapter, md5(lower(btrim(prompt))));

alter table problems add column if not exists diagram_svg text;
alter table problem_answers add column if not exists solved_by text default 'guide';   -- guide | parent | llm
alter table problem_answers add column if not exists verified boolean default true;

-- ---- add_questions now skips what it already has ------------------------
create or replace function add_questions(p_exam text, p_strand text, p_rows jsonb)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_bank exam_banks;
  v_chapter int;
  v_title text := p_exam || ' · ' || coalesce(nullif(p_strand,''), 'General');
  v_idx int; v_n int := 0; v_dupes int := 0;
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
    if coalesce(btrim(r->>'q'), '') = '' then continue; end if;

    -- the same question, word for word, is already in this strand
    if exists (select 1 from problems
               where chapter = v_chapter
                 and md5(lower(btrim(prompt))) = md5(lower(btrim(r->>'q')))) then
      v_dupes := v_dupes + 1;
      continue;
    end if;

    v_idx := v_idx + 1; v_n := v_n + 1;
    insert into problems (chapter, idx, prompt, difficulty, technique_tags, source, diagram_svg)
    values (v_chapter, v_idx, btrim(r->>'q'), coalesce((r->>'d')::int, 2),
            array[coalesce(nullif(p_strand,''), 'General')], v_bank.kind,
            nullif(btrim(r->>'svg'), ''));

    insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified)
    values (v_chapter, v_idx,
            coalesce(nullif(btrim(r->>'a'),''), 'Marked by hand.'),
            coalesce(nullif(btrim(r->>'a'),''), 'Marked by hand.'),
            nullif(btrim(r->>'a'),''),
            case when coalesce(btrim(r->>'a'),'') = '' then 'manual' else 'auto' end,
            'parent',
            true);

    insert into exam_map (exam, chapter, idx) values (p_exam, v_chapter, v_idx)
    on conflict do nothing;
  end loop;

  update chapters set practice = (select count(*) from problems where chapter = v_chapter) where n = v_chapter;

  return json_build_object('exam', p_exam, 'strand', v_title, 'chapter', v_chapter,
                           'added', v_n, 'skipped_duplicates', v_dupes);
end $$;

-- ---- the questions the app hands out now carry a diagram ----------------
create or replace function next_in_chapter(p_chapter int, p_count int default 4)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t) order by t.idx), '[]'::json)
  from (
    select p.chapter, p.idx, p.prompt, p.difficulty, p.diagram_svg
    from problems p
    where p.chapter = p_chapter
      and not exists (select 1 from attempts a
                      where a.student_id = auth.uid()
                        and a.chapter = p.chapter and a.idx = p.idx and a.ok)
    order by p.idx
    limit greatest(1, coalesce(p_count, 4))
  ) t;
$$;

create or replace function due_reviews(p_count int default 5)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t)), '[]'::json)
  from (
    select p.chapter, p.idx, p.prompt, p.difficulty, p.diagram_svg
    from weak_queue w
    join problems p on p.chapter = w.chapter and p.idx = w.idx
    where w.student_id = auth.uid()
      and coalesce(w.next_review, current_date) <= current_date
    order by w.next_review nulls first
    limit greatest(1, coalesce(p_count, 5))
  ) t;
$$;
