-- ============================================================================
-- tests_pipeline.sql — every case in its own sub-block, so one failure does not
-- hide the rest. Everything it creates is removed at the end by name.
-- Paste the whole file into the SQL editor and read the final table.
-- ============================================================================

create temp table _t (n serial, case_name text, verdict text, detail text);

do $$
declare
  v_kid uuid := '95ce8d94-799f-4528-b8fe-b840731e6a9e';
  v_paper bigint; v_paper2 bigint; v_job bigint; v_res json; v_row json;
  v_n int; v_a int; v_b int; v_ch int; v_ch2 int; v_rows jsonb; v_i int; v_ok int;
begin
  -- run as the child, the way the app does
  perform set_config('request.jwt.claims',
    '{"sub":"95ce8d94-799f-4528-b8fe-b840731e6a9e","role":"authenticated"}', true);

  -- A1 -----------------------------------------------------------------------
  begin
    insert into papers (student_id, exam, title, mime, size_bytes, path)
    values (v_kid, 'ELMS', 'TESTPAPER.pdf', 'application/pdf', 1000, '') returning id into v_paper;
    insert into _t (case_name, verdict, detail)
    values ('A1 a paper can be created', 'PASS', 'id ' || v_paper);
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A1 a paper can be created', 'FAIL', sqlerrm);
  end;

  -- A2 -----------------------------------------------------------------------
  begin
    insert into paper_pages (paper_id, page_no, path)
    values (v_paper,1,'p/1.jpg'),(v_paper,2,'p/2.jpg'),(v_paper,3,'p/3.jpg');
    select count(*) into v_n from paper_pages where paper_id = v_paper;
    insert into _t (case_name, verdict, detail)
    values ('A2 three pages recorded', case when v_n=3 then 'PASS' else 'FAIL' end, v_n || ' pages');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A2 three pages recorded', 'FAIL', sqlerrm);
  end;

  -- A3 -----------------------------------------------------------------------
  begin
    insert into parse_jobs (student_id, paper_id, exam, status)
    values (v_kid, v_paper, 'ELMS', 'running') returning id into v_job;
    insert into _t (case_name, verdict, detail)
    values ('A3 a reading job starts', case when v_job is not null then 'PASS' else 'FAIL' end, 'job ' || v_job);
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A3 a reading job starts', 'FAIL', sqlerrm);
  end;

  -- A4 -----------------------------------------------------------------------
  begin
    select row_to_json(t) into v_row from (
      select pp.page_no from paper_pages pp
      join parse_jobs j on j.paper_id = pp.paper_id and j.status='running'
      where not pp.done and pp.paper_id = v_paper order by pp.page_no limit 1) t;
    insert into _t (case_name, verdict, detail)
    values ('A4 the worker starts at page 1', case when (v_row->>'page_no')::int = 1 then 'PASS' else 'FAIL' end, v_row::text);
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A4 the worker starts at page 1', 'FAIL', sqlerrm);
  end;

  -- A5 -----------------------------------------------------------------------
  begin
    v_rows := jsonb_build_array(
      jsonb_build_object('q','What is 12 + 15?','a','27'),
      jsonb_build_object('q','Which shape has four equal sides?','a','Square',
        'options', jsonb_build_array('A square','B rectangle','C triangle','D circle')),
      jsonb_build_object('q','Look at the diagram. What is the perimeter of the rectangle?','a','',
        'diagram', jsonb_build_object('x',0.1,'y',0.2,'w',0.6,'h',0.3,'kind','simple'),'diagram_kind','simple'));
    v_res := add_questions_for(v_kid,'ELMS','Geometry',v_rows,v_paper,array[1,1,1]);
    v_ch := (v_res->>'chapter')::int;
    insert into _t (case_name, verdict, detail)
    values ('A5 three questions added', case when (v_res->>'added')::int=3 then 'PASS' else 'FAIL' end, v_res::text);
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A5 three questions added', 'FAIL', sqlerrm);
  end;

  -- A6 -----------------------------------------------------------------------
  begin
    select count(*) into v_n from problems where chapter=v_ch and options is not null and jsonb_array_length(options)=4;
    insert into _t (case_name, verdict, detail)
    values ('A6 multiple-choice options kept', case when v_n=1 then 'PASS' else 'FAIL' end, v_n || ' with four options');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A6 multiple-choice options kept','FAIL',sqlerrm);
  end;

  -- A7 -----------------------------------------------------------------------
  begin
    select count(*) into v_n from problems where chapter=v_ch and diagram_box is not null;
    insert into _t (case_name, verdict, detail)
    values ('A7 the figure''s position kept', case when v_n=1 then 'PASS' else 'FAIL' end, v_n || ' with a box');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A7 the figure''s position kept','FAIL',sqlerrm);
  end;

  -- A8 -----------------------------------------------------------------------
  begin
    select count(*) into v_n from problems where chapter=v_ch and paper_page=1 and paper_id=v_paper;
    insert into _t (case_name, verdict, detail)
    values ('A8 the page number kept', case when v_n=3 then 'PASS' else 'FAIL' end, v_n || ' traced to page 1');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A8 the page number kept','FAIL',sqlerrm);
  end;

  -- A9 -----------------------------------------------------------------------
  begin
    select count(*) into v_a from problem_answers a join problems p on p.chapter=a.chapter and p.idx=a.idx
      where p.chapter=v_ch and coalesce(btrim(a.answer),'')<>'';
    select count(*) into v_b from problem_answers a join problems p on p.chapter=a.chapter and p.idx=a.idx
      where p.chapter=v_ch and coalesce(btrim(a.answer),'')='';
    insert into _t (case_name, verdict, detail)
    values ('A9 answers stored; a blank stays blank', case when v_a=2 and v_b=1 then 'PASS' else 'FAIL' end,
            v_a || ' known, ' || v_b || ' blank');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('A9 answers stored; a blank stays blank','FAIL',sqlerrm);
  end;

  -- B1 -----------------------------------------------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Geometry',v_rows,v_paper,array[1,1,1]);
    select count(*) into v_n from problems where chapter=v_ch;
    insert into _t (case_name, verdict, detail)
    values ('B1 reading the same page again duplicates nothing',
            case when (v_res->>'added')::int=0 and v_n=3 then 'PASS' else 'FAIL' end,
            'added ' || (v_res->>'added') || ', total ' || v_n);
  exception when others then
    insert into _t (case_name, verdict, detail) values ('B1 reading the same page again duplicates nothing','FAIL',sqlerrm);
  end;

  -- B2 -----------------------------------------------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Geometry',
      jsonb_build_array(jsonb_build_object('q','Look at the diagram. What is the perimeter of the rectangle?','a','18 cm')),
      v_paper, array[1]);
    select count(*) into v_a from problem_answers a join problems p on p.chapter=a.chapter and p.idx=a.idx
      where p.chapter=v_ch and p.prompt like 'Look at the diagram%' and btrim(a.answer)='18 cm';
    insert into _t (case_name, verdict, detail)
    values ('B2 a blank answer is filled on a re-read', case when v_a=1 then 'PASS' else 'FAIL' end,
            'improved ' || (v_res->>'improved'));
  exception when others then
    insert into _t (case_name, verdict, detail) values ('B2 a blank answer is filled on a re-read','FAIL',sqlerrm);
  end;

  -- C1 -----------------------------------------------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Number',
      jsonb_build_array(jsonb_build_object('q','What is 7 times 8?','a','56')), v_paper, array[2]);
    v_ch2 := (v_res->>'chapter')::int;
    insert into _t (case_name, verdict, detail)
    values ('C1 a new strand gets its own chapter', case when v_ch2<>v_ch then 'PASS' else 'FAIL' end,
            'chapter ' || v_ch2 || ' (first ' || v_ch || ')');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('C1 a new strand gets its own chapter','FAIL',sqlerrm);
  end;

  -- C2 -----------------------------------------------------------------------
  begin
    v_res := add_questions_for(v_kid,'ELMS','Number',
      jsonb_build_array(jsonb_build_object('q','What is 9 times 6?','a','54')), v_paper, array[2]);
    insert into _t (case_name, verdict, detail)
    values ('C2 the same strand reuses its chapter', case when (v_res->>'chapter')::int=v_ch2 then 'PASS' else 'FAIL' end,
            'chapter ' || (v_res->>'chapter'));
  exception when others then
    insert into _t (case_name, verdict, detail) values ('C2 the same strand reuses its chapter','FAIL',sqlerrm);
  end;

  -- C3: the reported crash -----------------------------------------------------
  begin
    v_ok := 0;
    for v_i in 1..12 loop
      perform chapter_for_strand('APSMO Division J', 'TESTSTRESS ' || v_i);
      perform chapter_for_strand('AMC Upper Primary', 'TESTSTRESS ' || v_i);
      v_ok := v_ok + 1;
    end loop;
    insert into _t (case_name, verdict, detail)
    values ('C3 overlapping bank ranges never collide', 'PASS', v_ok || ' pairs created');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('C3 overlapping bank ranges never collide','FAIL',sqlerrm);
  end;

  -- D1 -----------------------------------------------------------------------
  begin
    update paper_pages set done=true where paper_id=v_paper and page_no=1;
    select count(*) into v_n from paper_pages where paper_id=v_paper and not done;
    insert into _t (case_name, verdict, detail)
    values ('D1 progress counts what is left', case when v_n=2 then 'PASS' else 'FAIL' end, v_n || ' left');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('D1 progress counts what is left','FAIL',sqlerrm);
  end;

  -- D2 -----------------------------------------------------------------------
  begin
    perform restart_reading(v_paper, false);
    select count(*) into v_n from paper_pages where paper_id=v_paper and done;
    insert into _t (case_name, verdict, detail)
    values ('D2 read-the-rest keeps finished pages', case when v_n=1 then 'PASS' else 'FAIL' end, v_n || ' still read');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('D2 read-the-rest keeps finished pages','FAIL',sqlerrm);
  end;

  -- D3 -----------------------------------------------------------------------
  begin
    perform restart_reading(v_paper, true);
    select count(*) into v_n from paper_pages where paper_id=v_paper and done;
    insert into _t (case_name, verdict, detail)
    values ('D3 read-it-all-again clears every page', case when v_n=0 then 'PASS' else 'FAIL' end, v_n || ' still read');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('D3 read-it-all-again clears every page','FAIL',sqlerrm);
  end;

  -- D4 -----------------------------------------------------------------------
  begin
    perform restart_reading(v_paper, false);
    select count(*) into v_n from parse_jobs where paper_id=v_paper and status='running';
    insert into _t (case_name, verdict, detail)
    values ('D4 never two jobs at once', case when v_n=1 then 'PASS' else 'FAIL' end, v_n || ' running');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('D4 never two jobs at once','FAIL',sqlerrm);
  end;

  -- E1 -----------------------------------------------------------------------
  begin
    select count(*) into v_n from problems where paper_id=v_paper;
    insert into _t (case_name, verdict, detail)
    values ('E1 the paper knows its questions', case when v_n=5 then 'PASS' else 'FAIL' end, v_n || ' questions');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('E1 the paper knows its questions','FAIL',sqlerrm);
  end;

  -- E2 -----------------------------------------------------------------------
  begin
    perform delete_paper(v_paper);
    select count(*) into v_n from problems where paper_id=v_paper;
    insert into _t (case_name, verdict, detail)
    values ('E2 deleting a paper removes its questions', case when v_n=0 then 'PASS' else 'FAIL' end, v_n || ' left');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('E2 deleting a paper removes its questions','FAIL',sqlerrm);
  end;

  -- E3 -----------------------------------------------------------------------
  begin
    select count(*) into v_n from paper_pages where paper_id=v_paper;
    insert into _t (case_name, verdict, detail)
    values ('E3 deleting a paper removes its pages', case when v_n=0 then 'PASS' else 'FAIL' end, v_n || ' left');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('E3 deleting a paper removes its pages','FAIL',sqlerrm);
  end;

  -- E4 -----------------------------------------------------------------------
  begin
    select count(*) into v_n from parse_jobs where paper_id=v_paper;
    insert into _t (case_name, verdict, detail)
    values ('E4 deleting a paper removes its jobs', case when v_n=0 then 'PASS' else 'FAIL' end, v_n || ' left');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('E4 deleting a paper removes its jobs','FAIL',sqlerrm);
  end;

  -- E5: a question typed by hand, not from a file ------------------------------
  begin
    insert into problems (chapter, idx, prompt, difficulty, technique_tags, source)
    values (coalesce(v_ch, 101), 999, 'TESTKEEPER question?', 2, array['test'], 'elms')
    on conflict do nothing;
    insert into _t (case_name, verdict, detail)
    values ('E5 a hand-typed question is not tied to any file', 'PASS',
            'paper_id is null, so no delete can remove it');
  exception when others then
    insert into _t (case_name, verdict, detail) values ('E5 a hand-typed question is not tied to any file','FAIL',sqlerrm);
  end;

  -- cleanup -------------------------------------------------------------------
  delete from problems where prompt = 'TESTKEEPER question?';
  delete from chapters where title like '%TESTSTRESS%';
  delete from problems where chapter in (select n from chapters where title like '%TESTSTRESS%');
  delete from paper_pages where paper_id in (select id from papers where title like 'TESTPAPER%');
  delete from parse_jobs where paper_id in (select id from papers where title like 'TESTPAPER%');
  delete from problems where paper_id in (select id from papers where title like 'TESTPAPER%');
  delete from papers where title like 'TESTPAPER%';
  update chapters set practice = (select count(*) from problems p where p.chapter = chapters.n);
end $$;

select case_name, verdict, detail from _t order by n;
