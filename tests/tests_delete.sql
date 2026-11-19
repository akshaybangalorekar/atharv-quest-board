-- ============================================================================
-- tests_delete.sql — does deleting a file leave anything behind?
-- Every case in its own sub-block; everything removed at the end.
-- ============================================================================

create temp table _d (n serial, case_name text, verdict text, detail text);

do $$
declare
  v_kid uuid := '95ce8d94-799f-4528-b8fe-b840731e6a9e';
  v_paper bigint; v_ch int; v_res json; v_n int; v_paths text[]; v_mock uuid;
begin
  perform set_config('request.jwt.claims', '{"sub":"95ce8d94-799f-4528-b8fe-b840731e6a9e","role":"authenticated"}', true);

  -- set a file up, with everything hanging off it
  insert into papers (student_id, exam, title, path) values (v_kid,'ELMS','TESTDEL.pdf','') returning id into v_paper;
  insert into paper_pages (paper_id, page_no, path) values (v_paper,1,'kid/page-1.jpg'),(v_paper,2,'kid/page-2.jpg');
  insert into parse_jobs (student_id, paper_id, exam, status) values (v_kid, v_paper, 'ELMS', 'running');
  v_res := add_questions_for(v_kid,'ELMS','Deletable',
    jsonb_build_array(
      jsonb_build_object('q','TESTDEL one?','a','1'),
      jsonb_build_object('q','TESTDEL two?','a','2')),
    v_paper, array[1,2]);
  v_ch := (v_res->>'chapter')::int;

  -- a child answers one of them, and it becomes a weak spot
  insert into attempts (student_id, chapter, idx, ok, answer_given, created_at)
  values (v_kid, v_ch, 1, false, 'wrong', now());
  insert into weak_queue (student_id, chapter, idx, technique, misses)
  values (v_kid, v_ch, 1, 'Deletable', 1);
  insert into exam_mocks (student_id, kind, score, total, pct)
  values (v_kid, 'test', 0, 1, 0) returning id into v_mock;
  insert into exam_items (exam_id, chapter, idx) values (v_mock, v_ch, 1);

  -- 1. the paths come back, so the files can be removed too
  begin
    v_paths := paper_objects(v_paper);
    insert into _d (case_name, verdict, detail)
    values ('1 the stored page paths are returned',
      case when array_length(v_paths,1) = 2 then 'PASS' else 'FAIL' end, array_to_string(v_paths, ', '));
  exception when others then
    insert into _d (case_name, verdict, detail) values ('1 the stored page paths are returned','FAIL',sqlerrm);
  end;

  -- 2. delete, and it says what it took
  begin
    v_res := delete_paper(v_paper);
    insert into _d (case_name, verdict, detail)
    values ('2 the delete reports what it removed',
      case when (v_res->>'questions_removed')::int = 2 then 'PASS' else 'FAIL' end, v_res::text);
  exception when others then
    insert into _d (case_name, verdict, detail) values ('2 the delete reports what it removed','FAIL',sqlerrm);
  end;

  -- 3..8 nothing left behind
  begin
    select count(*) into v_n from problems where prompt like 'TESTDEL%';
    insert into _d (case_name, verdict, detail)
    values ('3 no questions left', case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' left');
  end;

  begin
    select count(*) into v_n from problem_answers a
      where not exists (select 1 from problems p where p.chapter = a.chapter and p.idx = a.idx);
    insert into _d (case_name, verdict, detail)
    values ('4 no orphan answers anywhere', case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' orphans');
  end;

  begin
    select count(*) into v_n from attempts a
      where not exists (select 1 from problems p where p.chapter = a.chapter and p.idx = a.idx);
    insert into _d (case_name, verdict, detail)
    values ('5 no orphan attempts anywhere', case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' orphans');
  end;

  begin
    select count(*) into v_n from weak_queue w
      where not exists (select 1 from problems p where p.chapter = w.chapter);
    insert into _d (case_name, verdict, detail)
    values ('6 no orphan weak-queue entries', case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' orphans');
  end;

  begin
    select count(*) into v_n from exam_items e
      where not exists (select 1 from problems p where p.chapter = e.chapter and p.idx = e.idx);
    insert into _d (case_name, verdict, detail)
    values ('7 no orphan test items', case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' orphans');
  end;

  begin
    select count(*) into v_n from paper_pages where paper_id = v_paper;
    insert into _d (case_name, verdict, detail)
    values ('8 no page rows left', case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' left');
  end;

  begin
    select count(*) into v_n from parse_jobs where paper_id = v_paper;
    insert into _d (case_name, verdict, detail)
    values ('9 no reading jobs left', case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' left');
  end;

  begin
    select coalesce(practice, -1) into v_n from chapters where n = v_ch;
    insert into _d (case_name, verdict, detail)
    values ('10 the chapter count goes back to zero', case when v_n = 0 then 'PASS' else 'FAIL' end,
            'practice ' || v_n);
  end;

  -- 11. a fresh question in that same slot does not inherit the old attempt
  begin
    v_res := add_questions_for(v_kid,'ELMS','Deletable',
      jsonb_build_array(jsonb_build_object('q','TESTDEL three?','a','3')), null, null);
    select count(*) into v_n from attempts a join problems p on p.chapter = a.chapter and p.idx = a.idx
      where p.prompt = 'TESTDEL three?';
    insert into _d (case_name, verdict, detail)
    values ('11 a new question never inherits an old attempt',
      case when v_n = 0 then 'PASS' else 'FAIL' end, v_n || ' inherited');
  exception when others then
    insert into _d (case_name, verdict, detail) values ('11 a new question never inherits an old attempt','FAIL',sqlerrm);
  end;

  -- cleanup
  delete from problems where prompt like 'TESTDEL%';
  delete from problem_answers where not exists (select 1 from problems p where p.chapter = problem_answers.chapter and p.idx = problem_answers.idx);
  delete from attempts where not exists (select 1 from problems p where p.chapter = attempts.chapter and p.idx = attempts.idx);
  delete from weak_queue where not exists (select 1 from problems p where p.chapter = weak_queue.chapter);
  delete from exam_items where not exists (select 1 from problems p where p.chapter = exam_items.chapter and p.idx = exam_items.idx);
  delete from exam_mocks where kind = 'test';
  delete from chapters where title like '%· Deletable%';
  update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
end $$;

select case_name, verdict, detail from _d order by n;
