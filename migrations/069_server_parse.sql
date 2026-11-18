-- ============================================================================
-- 069_server_parse.sql
-- Reading moves off the browser. The upload still renders the pages — a web
-- page has to, because there is no PDF renderer on the server — but the model
-- calls and the writing of questions now happen in a function, one page at a
-- time, so closing the browser no longer stops the work: it resumes wherever it
-- left off, from any device.
-- Run after 068. Safe to re-run.
-- ============================================================================

create table if not exists paper_pages (
  paper_id bigint not null references papers(id) on delete cascade,
  page_no int not null,
  path text not null,
  done boolean default false,
  primary key (paper_id, page_no)
);
alter table paper_pages enable row level security;
drop policy if exists "own paper pages" on paper_pages;
create policy "own paper pages" on paper_pages for all to authenticated
  using (exists (select 1 from papers p where p.id = paper_id
                 and (p.student_id = auth.uid() or is_guardian(p.student_id))))
  with check (exists (select 1 from papers p where p.id = paper_id
                 and (p.student_id = auth.uid() or is_guardian(p.student_id))));

alter table parse_jobs add column if not exists paper_id_ref bigint;
alter table parse_jobs add column if not exists next_page int default 1;

-- what the worker should do next, for this child
create or replace function next_parse_page()
returns json
language sql security definer set search_path = public as $$
  select row_to_json(t) from (
    select pp.paper_id, pp.page_no, pp.path, j.id as job_id, j.exam
    from paper_pages pp
    join papers p on p.id = pp.paper_id
    join lateral (
      select id, exam from parse_jobs
      where paper_id = pp.paper_id and status = 'running'
      order by created_at desc limit 1
    ) j on true
    where not pp.done
      and p.student_id = coalesce(viewing_student(), auth.uid())
    order by pp.paper_id, pp.page_no
    limit 1
  ) t;
$$;

create or replace function mark_page_done(p_paper bigint, p_page int)
returns void
language sql security definer set search_path = public as $$
  update paper_pages set done = true where paper_id = p_paper and page_no = p_page;
$$;

grant execute on function next_parse_page() to authenticated;
grant execute on function mark_page_done(bigint, int) to authenticated;
