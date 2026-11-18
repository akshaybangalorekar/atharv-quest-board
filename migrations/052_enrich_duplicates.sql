-- ============================================================================
-- 052_enrich_duplicates.sql
-- A duplicate used to be thrown away, which meant re-uploading a paper could
-- never fix the questions already in the bank: the old row — with no options
-- and no page — stayed, and the better one was skipped.
--
-- Now a duplicate is enriched instead: the page it came from, the multiple
-- choice options, and an answer if one was missing. Nothing is duplicated.
-- Run after 051. Safe to re-run.
-- ============================================================================

create or replace function add_questions(
  p_exam text, p_strand text, p_rows jsonb,
  p_paper bigint default null, p_pages int[] default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_bank exam_banks;
  v_chapter int;
  v_title text := p_exam || ' · ' || coalesce(nullif(p_strand,''), 'General');
  v_idx int; v_n int := 0; v_dupes int := 0; v_fixed int := 0;
  v_i int := 0;
  v_existing int;
  v_page int;
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
    v_i := v_i + 1;
    if coalesce(btrim(r->>'q'), '') = '' then continue; end if;
    v_page := case when p_pages is null then null else p_pages[v_i] end;

    -- already here? then make it better rather than skipping it
    select p.idx into v_existing
    from problems p
    where p.chapter = v_chapter
      and md5(lower(btrim(p.prompt))) = md5(lower(btrim(r->>'q')))
    limit 1;

    if v_existing is not null then
      v_dupes := v_dupes + 1;
      update problems p set
        options    = coalesce(case when jsonb_typeof(r->'options') = 'array'
                                    and jsonb_array_length(r->'options') >= 2
                                   then r->'options' end, p.options),
        paper_id   = coalesce(p_paper, p.paper_id),
        paper_page = coalesce(v_page, p.paper_page)
      where p.chapter = v_chapter and p.idx = v_existing;

      if coalesce(btrim(r->>'a'), '') <> '' then
        update problem_answers a set
          answer = case when coalesce(btrim(a.answer),'') = '' then btrim(r->>'a') else a.answer end,
          answer_key = coalesce(a.answer_key, nullif(btrim(r->>'a'),'')),
          mark_mode = 'auto'
        where a.chapter = v_chapter and a.idx = v_existing;
      end if;
      v_fixed := v_fixed + 1;
      continue;
    end if;

    v_idx := v_idx + 1; v_n := v_n + 1;
    insert into problems (chapter, idx, prompt, difficulty, technique_tags, source,
                          diagram_svg, paper_id, paper_page, options)
    values (
      v_chapter, v_idx, btrim(r->>'q'), 2,
      array[p_strand]::text[], v_bank.kind, null,
      p_paper, v_page,
      case when jsonb_typeof(r->'options') = 'array' and jsonb_array_length(r->'options') >= 2
           then r->'options' else null end
    );
    insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified)
    values (v_chapter, v_idx, coalesce(nullif(btrim(r->>'a'),''), ''), null,
            nullif(btrim(r->>'a'),''), case when coalesce(btrim(r->>'a'),'') = '' then 'manual' else 'auto' end,
            'parent', true)
    on conflict (chapter, idx) do nothing;
  end loop;

  update chapters set practice = (select count(*) from problems where chapter = v_chapter) where n = v_chapter;
  update papers set questions = coalesce(questions,0) + v_n where id = p_paper;

  return json_build_object('added', v_n, 'skipped_duplicates', v_dupes, 'improved', v_fixed,
                           'chapter', v_chapter, 'strand', v_strand);
end $$;
