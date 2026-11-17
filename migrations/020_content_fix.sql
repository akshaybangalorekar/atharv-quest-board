-- ============================================================================
-- 020_content_fix.sql
-- The coach may check and correct the question bank — but every change is
-- recorded, and nothing is written until a parent approves it.
-- Run after 019. Safe to re-run.
-- ============================================================================

create table if not exists content_changes (
  id bigserial primary key,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz default now(),
  chapter int not null,
  idx int not null,
  before_answer text,
  after_answer text,
  before_method text,
  after_method text,
  reason text,
  source text default 'llm'          -- llm | parent
);
alter table content_changes enable row level security;

drop policy if exists "parent reads changes" on content_changes;
create policy "parent reads changes" on content_changes for select to authenticated
  using (is_parent());

drop policy if exists "parent writes changes" on content_changes;
create policy "parent writes changes" on content_changes for insert to authenticated
  with check (is_parent());

create index if not exists content_changes_recent on content_changes(changed_at desc);

-- the questions most likely to be wrong, worst first
create or replace function suspect_questions(p_limit int default 12)
returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(row_to_json(t) order by t.priority, t.chapter, t.idx), '[]'::json)
  from (
    select p.chapter, p.idx, p.prompt, a.answer_key, a.method, a.solved_by, a.verified,
           case when a.answer_key is null then 1
                when a.solved_by = 'llm' and not a.verified then 2
                when p.prompt ilike '%diagram in the paper%' then 3
                else 4 end as priority
    from problems p
    join problem_answers a on a.chapter = p.chapter and a.idx = p.idx
    where is_parent()
      and (a.answer_key is null
           or (a.solved_by = 'llm' and not a.verified)
           or p.prompt ilike '%diagram in the paper%')
    order by priority, p.chapter, p.idx
    limit greatest(1, coalesce(p_limit, 12))
  ) t;
$$;

create or replace function apply_content_fix(
  p_chapter int, p_idx int, p_answer text, p_method text, p_reason text default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_before_a text; v_before_m text;
begin
  if not is_parent() then
    raise exception 'only a parent can change the question bank' using errcode = '42501';
  end if;

  select answer_key, method into v_before_a, v_before_m
  from problem_answers where chapter = p_chapter and idx = p_idx;

  update problem_answers
     set answer_key = nullif(btrim(p_answer), ''),
         method = coalesce(nullif(btrim(p_method), ''), method),
         answer = coalesce(nullif(btrim(p_method), ''), answer),
         mark_mode = case when nullif(btrim(p_answer), '') is null then 'manual' else 'auto' end,
         solved_by = 'llm',
         verified = true
   where chapter = p_chapter and idx = p_idx;

  insert into content_changes (changed_by, chapter, idx, before_answer, after_answer,
                               before_method, after_method, reason, source)
  values (auth.uid(), p_chapter, p_idx, v_before_a, nullif(btrim(p_answer),''),
          v_before_m, nullif(btrim(p_method),''), p_reason, 'llm');

  return json_build_object('chapter', p_chapter, 'idx', p_idx,
                           'was', v_before_a, 'now', nullif(btrim(p_answer),''));
end $$;
