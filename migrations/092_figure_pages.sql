-- ============================================================================
-- 092_figure_pages.sql
-- A figure is not always on the same page as its question: a question on page 30
-- can say "see the diagram" and the diagram sits on page 31. It can also be one
-- figure shared by three questions. The question now records which page its
-- figure is on, so the app can cut it out from the right page.
-- Run after 091. Safe to re-run.
-- ============================================================================

alter table problems add column if not exists figure_page int;

create or replace function add_questions_for(
  p_student uuid, p_exam text, p_strand text, p_rows jsonb,
  p_paper bigint default null, p_pages int[] default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_bank exam_banks;
  v_chapter int;
  v_idx int; v_n int := 0; v_dupes int := 0; v_fixed int := 0;
  v_i int := 0; v_existing int; v_page int; v_fig text; v_kind text; v_box jsonb; v_fpage int;
  r jsonb;
begin
  select * into v_bank from exam_banks where exam = p_exam;
  if not found then raise exception 'unknown exam %, register it in exam_banks first', p_exam; end if;

  v_chapter := chapter_for_strand(p_exam, p_strand);
  select coalesce(max(idx), 0) into v_idx from problems where chapter = v_chapter;

  for r in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    if coalesce(btrim(r->>'q'), '') = '' then continue; end if;
    v_page  := case when p_pages is null then null else p_pages[v_i] end;
    v_fig   := nullif(btrim(coalesce(r->>'diagram_url','')), '');
    v_kind  := nullif(btrim(coalesce(r->>'diagram_kind','')), '');
    v_box   := case when jsonb_typeof(r->'diagram') = 'object' then r->'diagram' end;
    v_fpage := case when coalesce(r->>'figure_page','') ~ '^[0-9]+$' then (r->>'figure_page')::int end;

    select p.idx into v_existing
    from problems p
    where p.chapter = v_chapter
      and md5(lower(btrim(p.prompt))) = md5(lower(btrim(r->>'q')))
    limit 1;

    if v_existing is not null then
      v_dupes := v_dupes + 1;
      update problems p set
        options      = coalesce(case when jsonb_typeof(r->'options') = 'array'
                                      and jsonb_array_length(r->'options') >= 2
                                     then r->'options' end, p.options),
        paper_id     = coalesce(p_paper, p.paper_id),
        paper_page   = coalesce(v_page, p.paper_page),
        diagram_url  = coalesce(v_fig, p.diagram_url),
        diagram_kind = coalesce(v_kind, p.diagram_kind),
        diagram_box  = coalesce(v_box, p.diagram_box),
        figure_page  = coalesce(v_fpage, p.figure_page)
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
                          diagram_svg, paper_id, paper_page, options,
                          diagram_url, diagram_kind, diagram_box, figure_page)
    values (
      v_chapter, v_idx, btrim(r->>'q'), 2,
      array[p_strand]::text[], v_bank.kind, null,
      p_paper, v_page,
      case when jsonb_typeof(r->'options') = 'array' and jsonb_array_length(r->'options') >= 2
           then r->'options' else null end,
      v_fig, v_kind, v_box, v_fpage
    );
    insert into problem_answers (chapter, idx, answer, method, answer_key, mark_mode, solved_by, verified)
    values (v_chapter, v_idx, coalesce(nullif(btrim(r->>'a'),''), ''), null,
            nullif(btrim(r->>'a'),''), case when coalesce(btrim(r->>'a'),'') = '' then 'manual' else 'auto' end,
            'reader', true)
    on conflict (chapter, idx) do nothing;
  end loop;

  update chapters set practice = (select count(*) from problems where chapter = v_chapter) where n = v_chapter;
  if p_paper is not null then
    update papers set questions = coalesce(questions,0) + v_n where id = p_paper;
  end if;

  return json_build_object('added', v_n, 'skipped_duplicates', v_dupes, 'improved', v_fixed,
                           'chapter', v_chapter, 'strand', coalesce(nullif(p_strand,''), 'General'));
end $$;

revoke all on function add_questions_for(uuid, text, text, jsonb, bigint, int[]) from public, anon, authenticated;
grant execute on function add_questions_for(uuid, text, text, jsonb, bigint, int[]) to service_role;
