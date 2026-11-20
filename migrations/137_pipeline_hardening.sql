-- 137_pipeline_hardening.sql
--   authority becomes a foreign key to exams, not a string prefix
--   every correction is kept in question_history
--   a job retries twice with backoff before it is called failed
alter table source_docs add column if not exists authority_exam bigint references exams(id) on delete set null;
update source_docs d set authority_exam = e.id from exams e
 where d.authority is not null and d.authority_exam is null and split_part(d.authority, '_', 2) = e.key;

create table if not exists question_history (
  id bigserial primary key, chapter int not null, idx int not null,
  old_prompt text, new_prompt text, old_status text, new_status text,
  note text, changed_at timestamptz not null default now());
create index if not exists question_history_q on question_history (chapter, idx, changed_at desc);

create or replace function log_question_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.prompt is distinct from old.prompt) or (new.status is distinct from old.status) then
    insert into question_history (chapter, idx, old_prompt, new_prompt, old_status, new_status, note)
    values (new.chapter, new.idx, old.prompt, new.prompt, old.status, new.status, new.status_note);
  end if;
  return new;
end $$;

drop trigger if exists problems_history on problems;
create trigger problems_history after update on problems
  for each row execute function log_question_change();

alter table jobs add column if not exists attempts int not null default 0;
alter table jobs add column if not exists next_try_at timestamptz;
