-- ============================================================================
-- 054_parse_jobs.sql
-- Uploading and reading are two different jobs. The file is saved first, with a
-- progress bar; the reading then happens in the background, and when it is done
-- a note is waiting at the top of whichever screen he is on.
-- Run after 053. Safe to re-run.
-- ============================================================================

create table if not exists parse_jobs (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  paper_id bigint references papers(id) on delete cascade,
  exam text,
  strand text,
  status text not null default 'running',   -- running | done | failed
  pages_total int default 0,
  pages_done int default 0,
  added int default 0,
  unanswered int default 0,
  note text,
  seen boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table parse_jobs enable row level security;
drop policy if exists "own jobs" on parse_jobs;
create policy "own jobs" on parse_jobs for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));

create or replace function start_parse_job(p_paper bigint, p_exam text, p_pages int)
returns bigint
language plpgsql security definer set search_path = public as $$
declare v uuid := auth.uid(); v_id bigint;
begin
  if v is null then raise exception 'not signed in' using errcode = '28000'; end if;
  insert into parse_jobs (student_id, paper_id, exam, pages_total)
  values (v, p_paper, p_exam, coalesce(p_pages,0))
  returning id into v_id;
  return v_id;
end $$;

create or replace function finish_parse_job(
  p_id bigint, p_added int, p_unanswered int, p_strand text, p_pages_done int, p_failed boolean default false
) returns void
language plpgsql security definer set search_path = public as $$
begin
  update parse_jobs set
    status = case when p_failed then 'failed' else 'done' end,
    added = coalesce(p_added,0),
    unanswered = coalesce(p_unanswered,0),
    strand = coalesce(p_strand, strand),
    pages_done = coalesce(p_pages_done, pages_done),
    note = case when p_failed then 'The reading failed. The file is saved — try again from the parent view.'
                else 'Questions added to ' || coalesce(p_strand,'the bank') || '. '
                     || coalesce(p_added,0) || ' in all'
                     || case when coalesce(p_unanswered,0) > 0
                             then ', ' || p_unanswered || ' without an answer yet.' else '.' end
           end,
    updated_at = now()
  where id = p_id;
end $$;

-- the newest note that has not been shown yet
create or replace function parse_note()
returns json
language sql security definer set search_path = public as $$
  select row_to_json(t) from (
    select id, note, status, added, unanswered, strand
    from parse_jobs
    where student_id = auth.uid() and status in ('done','failed') and coalesce(note,'') <> '' and not seen
    order by updated_at desc limit 1
  ) t;
$$;

create or replace function dismiss_parse_note(p_id bigint)
returns void
language sql security definer set search_path = public as $$
  update parse_jobs set seen = true where id = p_id and student_id = auth.uid();
$$;

grant execute on function start_parse_job(bigint, text, int) to authenticated;
grant execute on function finish_parse_job(bigint, int, int, text, int, boolean) to authenticated;
grant execute on function parse_note() to authenticated;
grant execute on function dismiss_parse_note(bigint) to authenticated;
