-- ============================================================================
-- tests_edges.sql — the awkward cases: odd input, bad shapes, twice in a row,
-- and the empty state. Same style as the first suite: every case in its own
-- sub-block, everything it creates removed at the end.
-- ============================================================================

create temp table _e (n serial, case_name text, verdict text, detail text);

do $$
declare
  v_kid uuid := '95ce8d94-799f-4528-b8fe-b840731e6a9e';
  v_paper bigint; v_res json; v_n int; v_ch int; v_msg text; v_row json; v_ok boolean;
begin
  perform set_config('request.jwt.claims', '{"sub":"95ce8d94-799f-4528-b8fe-b840731e6a9e","role":"authenticated"}', true);

  insert into papers (student_id, exam, title, path) values (v_kid,'ELMS','TESTEDGE.pdf','') returning id into v_paper;

  -- 1. empty list of rows -----------------------------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Edge', '[]'::jsonb, v_paper, null);
    insert into _e (case_name, verdict, detail) values ('1 an empty page adds nothing',
      case when (v_res->>'added')::int = 0 then 'PASS' else 'FAIL' end, v_res::text);
  exception when others then
    insert into _e (case_name, verdict, detail) values ('1 an empty page adds nothing','FAIL',sqlerrm);
  end;

  -- 2. a row with no question text is skipped ---------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Edge',
      jsonb_build_array(jsonb_build_object('q','','a','4'), jsonb_build_object('q','Real one?','a','4')),
      v_paper, null);
    insert into _e (case_name, verdict, detail) values ('2 a blank question is skipped',
      case when (v_res->>'added')::int = 1 then 'PASS' else 'FAIL' end, v_res::text);
  exception when others then
    insert into _e (case_name, verdict, detail) values ('2 a blank question is skipped','FAIL',sqlerrm);
  end;

  -- 3. options with only one choice are ignored ------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Edge',
      jsonb_build_array(jsonb_build_object('q','One option only?','a','1','options',jsonb_build_array('only one'))),
      v_paper, null);
    select count(*) into v_n from problems where prompt='One option only?' and options is not null;
    insert into _e (case_name, verdict, detail) values ('3 one option is not a choice list',
      case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' stored options');
  exception when others then
    insert into _e (case_name, verdict, detail) values ('3 one option is not a choice list','FAIL',sqlerrm);
  end;

  -- 4. a mangled figure box does not break the write -------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Edge',
      jsonb_build_array(jsonb_build_object('q','Bad box question?','a','2','diagram', jsonb_build_array(1,2,3))),
      v_paper, null);
    select count(*) into v_n from problems where prompt='Bad box question?';
    insert into _e (case_name, verdict, detail) values ('4 a mangled figure box is dropped, not fatal',
      case when v_n = 1 then 'PASS' else 'FAIL' end, v_n || ' stored');
  exception when others then
    insert into _e (case_name, verdict, detail) values ('4 a mangled figure box is dropped, not fatal','FAIL',sqlerrm);
  end;

  -- 5. the same words in two strands are two questions -----------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Strand A',
      jsonb_build_array(jsonb_build_object('q','What is 3 + 4?','a','7')), v_paper, null);
    v_res := add_questions_for(v_kid,'ELMS','Strand B',
      jsonb_build_array(jsonb_build_object('q','What is 3 + 4?','a','7')), v_paper, null);
    select count(*) into v_n from problems where prompt='What is 3 + 4?';
    insert into _e (case_name, verdict, detail) values ('5 the same words in two strands stay separate',
      case when v_n = 2 then 'PASS' else 'FAIL' end, v_n || ' stored');
  exception when others then
    insert into _e (case_name, verdict, detail) values ('5 the same words in two strands stay separate','FAIL',sqlerrm);
  end;

  -- 6. punctuation and unicode survive ---------------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Edge',
      jsonb_build_array(jsonb_build_object('q','What is 45° + 60°? Use π ≈ 3.14 — and “quote” it.','a','105°')),
      v_paper, null);
    select count(*) into v_n from problems where prompt like 'What is 45°%';
    insert into _e (case_name, verdict, detail) values ('6 degrees, pi and quotes survive',
      case when v_n = 1 then 'PASS' else 'FAIL' end, v_n || ' stored');
  exception when others then
    insert into _e (case_name, verdict, detail) values ('6 degrees, pi and quotes survive','FAIL',sqlerrm);
  end;

  -- 7. an unknown exam gives a clear message ---------------------------------
  begin
    begin
      perform add_questions_for(v_kid,'Not An Exam','Edge', jsonb_build_array(jsonb_build_object('q','x?','a','1')), v_paper, null);
      insert into _e (case_name, verdict, detail) values ('7 an unknown exam is refused clearly','FAIL','no error raised');
    exception when others then
      insert into _e (case_name, verdict, detail) values ('7 an unknown exam is refused clearly','PASS', sqlerrm);
    end;
  end;

  -- 8. progress with no job is simply null -----------------------------------
  begin
    delete from parse_jobs where student_id = v_kid and paper_id = v_paper;
    select parse_progress() into v_row;
    insert into _e (case_name, verdict, detail) values ('8 no job means no progress, not an error',
      case when v_row is null then 'PASS' else 'FAIL' end, coalesce(v_row::text,'null'));
  exception when others then
    insert into _e (case_name, verdict, detail) values ('8 no job means no progress, not an error','FAIL',sqlerrm);
  end;

  -- 9. a paper with no pages still appears in the list -----------------------
  begin
    select count(*) into v_n from json_array_elements(papers_to_read()) p
     where (p->>'id')::bigint = v_paper;
    insert into _e (case_name, verdict, detail) values ('9 an unprepared file still shows in the list',
      case when v_n = 1 then 'PASS' else 'FAIL' end, v_n || ' row');
  exception when others then
    insert into _e (case_name, verdict, detail) values ('9 an unprepared file still shows in the list','FAIL',sqlerrm);
  end;

  -- 10. two restarts in a row leave one job ----------------------------------
  begin
    perform restart_reading(v_paper, true);
    perform restart_reading(v_paper, true);
    select count(*) into v_n from parse_jobs where paper_id = v_paper and status='running';
    insert into _e (case_name, verdict, detail) values ('10 restarting twice leaves one job',
      case when v_n = 1 then 'PASS' else 'FAIL' end, v_n || ' running');
  exception when others then
    insert into _e (case_name, verdict, detail) values ('10 restarting twice leaves one job','FAIL',sqlerrm);
  end;

  -- 11. deleting twice gives a clean message --------------------------------
  begin
    perform delete_paper(v_paper);
    begin
      perform delete_paper(v_paper);
      insert into _e (case_name, verdict, detail) values ('11 deleting twice says so plainly','FAIL','no error');
    exception when others then
      insert into _e (case_name, verdict, detail) values ('11 deleting twice says so plainly','PASS',sqlerrm);
    end;
  exception when others then
    insert into _e (case_name, verdict, detail) values ('11 deleting twice says so plainly','FAIL',sqlerrm);
  end;

  -- 12. a question typed in the app, with no file behind it ------------------
  begin
    insert into papers (student_id, exam, title, path)
    values (v_kid,'ELMS','TESTEDGE2.pdf','') returning id into v_paper;
    v_ch := chapter_for_strand('ELMS','Typed');
    insert into problems (chapter, idx, prompt, difficulty, technique_tags, source)
    values (v_ch, 1, 'TESTTYPED question?', 2, array['typed'], 'elms');
    perform delete_paper(v_paper);
    select count(*) into v_n from problems where prompt='TESTTYPED question?';
    insert into _e (case_name, verdict, detail) values ('12 a typed question survives a file delete',
      case when v_n = 1 then 'PASS' else 'FAIL' end, v_n || ' left');
  exception when others then
    insert into _e (case_name, verdict, detail) values ('12 a typed question survives a file delete','FAIL',sqlerrm);
  end;

  -- cleanup ------------------------------------------------------------------
  delete from problems where prompt in ('TESTTYPED question?','What is 3 + 4?','Real one?','One option only?','Bad box question?');
  delete from problems where prompt like 'What is 45°%';
  delete from chapters where title like '%TESTSTRESS%' or title like '%· Edge%' or title like '%· Typed%'
     or title like '%· Strand A%' or title like '%· Strand B%';
  delete from papers where title like 'TESTEDGE%';
  delete from paper_pages where paper_id not in (select id from papers);
  delete from parse_jobs where paper_id not in (select id from papers);
  update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
end $$;

select case_name, verdict, detail from _e order by n;
