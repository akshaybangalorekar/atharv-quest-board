-- 136_one_status.sql — one lifecycle for a question: draft, provisional, cleared, failed.
alter table problems add column if not exists status text;
alter table problems add column if not exists status_note text;
alter table problems add column if not exists status_at timestamptz;

update problems set status = case
    when verify_note is not null or gate_state = 'failed' then 'failed'
    when gate_state = 'cleared' then 'cleared'
    when verified then 'provisional'
    else 'draft' end,
  status_note = coalesce(gate_note, verify_note),
  status_at = coalesce(gate_at, verified_at)
where status is null;

alter table problems alter column status set default 'draft';
alter table problems alter column status set not null;

create or replace view v_problems_ok as
  select p.* from problems p where p.status in ('provisional', 'cleared');

create or replace function set_question_status(p_chapter int, p_idx int, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_status not in ('draft','provisional','cleared','failed') then
    raise exception 'unknown status %', p_status using errcode = '22023';
  end if;
  update problems set status = p_status, status_note = p_note, status_at = now()
   where chapter = p_chapter and idx = p_idx;
end $$;
grant execute on function set_question_status(int, int, text, text) to authenticated;
