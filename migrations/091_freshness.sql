-- ============================================================================
-- 091_freshness.sql
-- The line "51% Olympiad · 25% Edutest" was a share of the week's teaching
-- time, not progress — it read like a score, and with a bank that grows it meant
-- less every day. This reports something true instead: when he last did work in
-- each exam, and how stale that is.
-- Run after 090. Safe to re-run.
-- ============================================================================

create or replace function family_freshness()
returns json
language sql security definer set search_path = public as $$
  with who as (select coalesce(viewing_student(), auth.uid()) as sid),
  fams as (
    select b.family,
           array_agg(distinct case when b.kind = 'olympiad' then 'book' else b.kind end) as kinds
    from exam_banks b where b.family is not null group by b.family
  ),
  last as (
    select f.family,
           (select max(a.created_at)::date from attempts a
              join problems p on p.chapter = a.chapter and p.idx = a.idx
             where p.source = any(f.kinds) and a.student_id = who.sid) as last_on,
           (select count(*) from attempts a
              join problems p on p.chapter = a.chapter and p.idx = a.idx
             where p.source = any(f.kinds) and a.student_id = who.sid) as tried
    from fams f, who
  )
  select coalesce(json_agg(json_build_object(
           'family', family,
           'label', case family when 'olympiad' then 'Olympiad' when 'aas' then 'AAS'
                                when 'edutest' then 'Edutest' when 'amc' then 'AMC'
                                when 'icas' then 'ICAS' else initcap(family) end,
           'last_on', last_on,
           'days_since', case when last_on is null then null
                              else ((now() at time zone 'Australia/Melbourne')::date - last_on) end,
           'tried', tried,
           'state', case
              when last_on is null then 'never'
              when ((now() at time zone 'Australia/Melbourne')::date - last_on) = 0 then 'today'
              when ((now() at time zone 'Australia/Melbourne')::date - last_on) = 1 then 'yesterday'
              when ((now() at time zone 'Australia/Melbourne')::date - last_on) <= 2 then 'recent'
              when ((now() at time zone 'Australia/Melbourne')::date - last_on) <= 4 then 'slipping'
              else 'cold' end
         ) order by family), '[]'::json)
  from last;
$$;

grant execute on function family_freshness() to authenticated;
