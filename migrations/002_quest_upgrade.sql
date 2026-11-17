-- ============================================================================
-- 002_quest_upgrade.sql
-- Upgrade from the current schema (001_schema.sql) to the one the Quest Board
-- needs. Run AFTER 001 and its seed. Safe to re-run.
--
-- What it changes, and why:
--   1. Answer key moves off `problems` into `problem_answers`, which the client
--      cannot read. Marking goes through submit_answer().
--   2. `attempts` becomes an append-only log (id per attempt) instead of one
--      row per question that gets overwritten.
--   3. `exam_items` stores which question was answered what in each test, so a
--      mock can be diagnosed instead of only scored.
--   4. Adds the tables the dashboard already assumes: examples, plan_days,
--      sessions, exam_calendar, guardians.
--   5. XP and marks are computed on the server. The client can no longer set
--      its own XP or quiz score.
--   6. Guardian (parent) read access, so the parent tab works without logging
--      in as the child.
--   7. Share links get an expiry, and the advisor warnings are cleared.
--
-- NOTE: step 2 drops problems.answer after copying it. Nothing is lost, but it
-- is a one-way change; run it when no client is reading that column.
-- ============================================================================

-- ---------- 0. adopt the prototype's table names (D6) ----------------------
-- The prototype's footer names chapter_progress, weak_queue, exam_mocks and
-- milestones. These three are the same tables under their old names.
alter table if exists chapter_meta     rename to chapter_progress;
alter table if exists reviews          rename to weak_queue;
alter table if exists exams            rename to exam_mocks;

-- ---------- 1. chapters: the tier the game unlocks on -----------------------
alter table chapters add column if not exists tier int;

-- ---------- 2. problems: difficulty, tags, page, and the answer key --------
alter table problems add column if not exists difficulty int default 2;
alter table problems add column if not exists technique_tags text[] default '{}';
alter table problems add column if not exists book_page int;
alter table problems add column if not exists has_diagram boolean default false;

create table if not exists problem_answers (
  chapter int not null,
  idx     int not null,
  answer  text not null,          -- the guide's method-and-answer line
  method  text,                   -- the shortcut, shown after marking
  answer_key text,                -- the short canonical value, null if manual
  primary key (chapter, idx),
  foreign key (chapter, idx) references problems(chapter, idx) on delete cascade
);
alter table problem_answers enable row level security;
-- No policy for `authenticated`: the client cannot read answers at all.
-- The service role and SECURITY DEFINER functions still can.

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='problems' and column_name='answer') then
    insert into problem_answers (chapter, idx, answer, method)
    select chapter, idx, answer, answer from problems
    on conflict (chapter, idx) do nothing;
    alter table problems drop column answer;
  end if;
end $$;

-- ---------- 3. examples: the 109 worked examples the teaching starts from --
create table if not exists examples (
  chapter int not null references chapters(n) on delete cascade,
  n int not null,
  prompt text not null,
  solution text not null,
  reviewed_at timestamptz,
  primary key (chapter, n)
);
alter table examples enable row level security;
drop policy if exists "read examples" on examples;
create policy "read examples" on examples for select to authenticated using (true);

-- ---------- 4. attempts: append-only --------------------------------------
do $$
begin
  if exists (select 1 from pg_constraint where conname='attempts_pkey'
             and conrelid='public.attempts'::regclass) then
    alter table attempts drop constraint attempts_pkey;
  end if;
end $$;
alter table attempts alter column ok drop not null;   -- null = not yet marked
alter table attempts add column if not exists id bigserial primary key;
alter table attempts add column if not exists created_at timestamptz default now();
alter table attempts add column if not exists answer_given text;
alter table attempts add column if not exists seconds int;
alter table attempts add column if not exists exam_id uuid;
create index if not exists attempts_student_time_idx on attempts(student_id, created_at desc);
create index if not exists attempts_question_idx on attempts(chapter, idx);

-- ---------- 5. exam_mocks: per-question detail ---------------------------------
alter table exam_mocks add column if not exists started_at timestamptz;
alter table exam_mocks add column if not exists submitted_at timestamptz;
alter table exam_mocks add column if not exists marks int;
alter table exam_mocks add column if not exists marks_total int;
alter table exam_mocks add column if not exists pass_bar int default 70;
create index if not exists exam_mocks_student_idx on exam_mocks(student_id, taken_at desc);

create table if not exists exam_items (
  exam_id uuid not null references exam_mocks(id) on delete cascade,
  chapter int not null,
  idx int not null,
  answer_given text,
  ok boolean,
  marks_awarded int default 0,
  primary key (exam_id, chapter, idx)
);
alter table exam_items enable row level security;

-- ---------- 6. plan_days: what today is meant to be ------------------------
create table if not exists plan_days (
  student_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  lane text not null,             -- Q | S | N | M | D | E | R
  chapter int,
  target_questions int default 0,
  minutes int default 30,
  note text,
  primary key (student_id, day, lane)
);
alter table plan_days enable row level security;

-- ---------- 7. sessions: streaks and missed days ---------------------------
create table if not exists sessions (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  lane text,
  minutes int default 0,
  status text default 'done',     -- done | partial | missed
  note text,
  created_at timestamptz default now()
);
alter table sessions enable row level security;
create index if not exists sessions_student_day_idx on sessions(student_id, day desc);

-- ---------- 8. exam_calendar: the countdowns the parent tab shows ---------
create table if not exists exam_calendar (
  id bigserial primary key,
  student_id uuid not null references auth.users(id) on delete cascade,
  exam text not null,             -- AMC Upper Primary | APSMO J | Camberwell AAS | ...
  sits_on date,
  date_status text default 'expected',  -- expected | confirmed | sat
  registration_opens date,
  registration_closes date,
  target text,                    -- '90/135', '4/5', '80%'
  note text,
  created_at timestamptz default now()
);
alter table exam_calendar enable row level security;

-- ---------- 9. guardians: the parent can read, not write ------------------
create table if not exists guardians (
  parent_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (parent_id, student_id)
);
alter table guardians enable row level security;

create or replace function is_guardian(p_student uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from guardians where parent_id = auth.uid() and student_id = p_student);
$$;

-- ---------- 10. profiles: time, streak, and no client-set XP --------------
alter table profiles add column if not exists timezone text default 'Australia/Melbourne';
alter table profiles add column if not exists streak_days int default 0;
alter table profiles add column if not exists last_session_date date;
alter table profiles add column if not exists weekly_minutes int default 120;
alter table profiles add column if not exists level int default 1;

-- ---------- 11. weak_queue: consecutive-correct tracking ---------------------
alter table weak_queue add column if not exists correct_streak int default 0;
alter table weak_queue add column if not exists last_seen date;

-- ---------- 9b. milestones (prototype name) -----------------------------
create table if not exists milestones (
  student_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  due_date date,
  hit_at timestamptz,
  status text default 'pending',      -- pending | ahead | on-track | behind | hit
  primary key (student_id, key)
);
alter table milestones enable row level security;

-- ---------- 12. policies ---------------------------------------------------
-- Own rows, rewritten so auth.uid() is evaluated once per query.
do $$
declare t text;
begin
  foreach t in array array['profiles','attempts','weak_queue','chapter_progress','badges','exam_mocks',
                           'exam_items','plan_days','sessions','exam_calendar','milestones'] loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "own rows" on %I', t);
  end loop;
end $$;

drop policy if exists "own rows" on profiles;
create policy "own rows" on profiles for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on attempts;
create policy "own rows" on attempts for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on weak_queue;
create policy "own rows" on weak_queue for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on chapter_progress;
create policy "own rows" on chapter_progress for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on badges;
create policy "own rows" on badges for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on exam_mocks;
create policy "own rows" on exam_mocks for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on plan_days;
create policy "own rows" on plan_days for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on sessions;
create policy "own rows" on sessions for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "own rows" on exam_calendar;
create policy "own rows" on exam_calendar for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));

-- exam_items belongs to an exam the student owns
drop policy if exists "own rows" on exam_items;
create policy "own rows" on exam_items for all to authenticated
  using (exists (select 1 from exam_mocks e where e.id = exam_id and e.student_id = (select auth.uid())))
  with check (exists (select 1 from exam_mocks e where e.id = exam_id and e.student_id = (select auth.uid())));

-- guardians see everything of their child, read-only
drop policy if exists "guardian read" on profiles;
create policy "guardian read" on profiles for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on attempts;
create policy "guardian read" on attempts for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on weak_queue;
create policy "guardian read" on weak_queue for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on chapter_progress;
create policy "guardian read" on chapter_progress for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on badges;
create policy "guardian read" on badges for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on exam_mocks;
create policy "guardian read" on exam_mocks for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on plan_days;
create policy "guardian read" on plan_days for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on sessions;
create policy "guardian read" on sessions for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian read" on exam_calendar;
create policy "guardian read" on exam_calendar for select to authenticated using (is_guardian(student_id));
drop policy if exists "own rows" on milestones;
create policy "own rows" on milestones for all to authenticated
  using (student_id = (select auth.uid())) with check (student_id = (select auth.uid()));
drop policy if exists "guardian read" on milestones;
create policy "guardian read" on milestones for select to authenticated using (is_guardian(student_id));
drop policy if exists "guardian own" on guardians;
create policy "guardian own" on guardians for select to authenticated
  using (parent_id = (select auth.uid()) or student_id = (select auth.uid()));

-- the child may edit his own settings but not his XP or level
revoke update on profiles from authenticated;
grant update (name, days_per_week, session_min, weekly_minutes, timezone, target_date)
  on profiles to authenticated;

-- ---------- 12b. XP and marks are set by the server only -------------------
-- Column grants alone are fragile: any blanket `grant update` undoes them.
-- This trigger holds even when the client has full table privileges.
create or replace function protect_progress()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated','anon') then
    if new.xp is distinct from old.xp
       or new.level is distinct from old.level
       or new.streak_days is distinct from old.streak_days
       or new.last_session_date is distinct from old.last_session_date then
      raise exception 'xp, level and streak are written by the server' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists protect_progress on profiles;
create trigger protect_progress before update on profiles
  for each row execute function protect_progress();

create or replace function protect_marks()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated','anon') then
    if new.quiz_best is distinct from old.quiz_best
       or new.weak is distinct from old.weak then
      raise exception 'quiz scores and weak flags are written by the server' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists protect_marks on chapter_progress;
create trigger protect_marks before update on chapter_progress
  for each row execute function protect_marks();

-- ---------- 13. share links expire ---------------------------------------
alter table share_links add column if not exists expires_at timestamptz;
create index if not exists share_links_student_idx on share_links(student_id);

create or replace function read_share(p_token text)
returns json language sql security definer set search_path = public as $$
  select json_build_object(
    'profile', (select to_json(p) from profiles p where p.student_id = sl.student_id),
    'chapters', coalesce((select json_agg(json_build_object('chapter',chapter,'quiz_best',quiz_best,'weak',weak))
                          from chapter_progress where student_id = sl.student_id),'[]'::json),
    'attempts', coalesce((select json_agg(json_build_object('chapter',chapter,'idx',idx,'ok',ok,'created_at',created_at)
                          order by created_at desc) from attempts where student_id = sl.student_id),'[]'::json),
    'badges', coalesce((select json_agg(key) from badges where student_id = sl.student_id),'[]'::json),
    'exam_mocks', coalesce((select json_agg(json_build_object('kind',kind,'scope',scope,'score',score,'total',total,
                          'pct',pct,'minutes',minutes,'taken_at',taken_at) order by taken_at desc)
                          from exam_mocks where student_id = sl.student_id),'[]'::json)
  )
  from share_links sl
  where sl.token = p_token
    and (sl.expires_at is null or sl.expires_at > now());
$$;
grant execute on function read_share(text) to anon, authenticated;

-- rls_auto_enable is a helper, not an API endpoint
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
             where n.nspname='public' and p.proname='rls_auto_enable') then
    execute 'revoke execute on function public.rls_auto_enable() from anon, authenticated';
  end if;
end $$;

-- ---------- 14. server-side scoring --------------------------------------
create or replace function normalize_answer(t text)
returns text language sql immutable as $$
  select lower(regexp_replace(coalesce(t,''), '[\s,]+', '', 'g'));
$$;

create or replace function xp_for(p_tier int, p_hints int, p_working boolean, p_mode text)
returns int language sql immutable as $$
  select greatest(0, round(
      (case coalesce(p_tier,1) when 1 then 10 when 2 then 15 when 3 then 20 when 4 then 30 else 10 end)
      * (case when coalesce(p_hints,0) = 0 then 1.5 else 1 end)          -- no-hint bonus
      * (case when coalesce(p_mode,'quest') in ('mock','boss','gauntlet','quiz') then 1.5 else 1 end)
      + (case when coalesce(p_working,false) then 5 else 0 end)
      - 5 * greatest(coalesce(p_hints,0) - 1, 0)                        -- extra hints cost
  ))::int;
$$;

-- Mark one answer. Returns correct (null = needs a human), the method to teach,
-- and the XP awarded. Everything is written server-side.
create or replace function submit_answer(
  p_chapter int,
  p_idx int,
  p_answer text,
  p_hints int default 0,
  p_working boolean default false,
  p_mode text default 'quest',
  p_seconds int default null,
  p_exam_id uuid default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_key text;
  v_method text;
  v_tier int;
  v_correct boolean;
  v_xp int := 0;
  v_misses int;
  v_streak int;
  v_reveal boolean;
begin
  if v_student is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  select a.answer_key, a.method, coalesce(c.tier,1)
    into v_key, v_method, v_tier
  from problem_answers a
  join problems p on p.chapter = a.chapter and p.idx = a.idx
  join chapters c on c.n = p.chapter
  where a.chapter = p_chapter and a.idx = p_idx;

  if not found then
    raise exception 'no such question % %', p_chapter, p_idx;
  end if;

  if v_key is null then
    v_correct := null;                                   -- manual marking
  else
    v_correct := normalize_answer(p_answer) = normalize_answer(v_key);
  end if;

  if v_correct is true then
    v_xp := xp_for(v_tier, p_hints, p_working, p_mode);
  end if;

  insert into attempts (student_id, chapter, idx, ok, hints, working, xp, mode,
                        answer_given, seconds, exam_id, updated_at)
  values (v_student, p_chapter, p_idx, v_correct, coalesce(p_hints,0),
          coalesce(p_working,false), v_xp, coalesce(p_mode,'quest'), p_answer,
          p_seconds, p_exam_id, now());

  if p_exam_id is not null then
    insert into exam_items (exam_id, chapter, idx, answer_given, ok, marks_awarded)
    values (p_exam_id, p_chapter, p_idx, p_answer, v_correct, 0)
    on conflict (exam_id, chapter, idx) do update
      set answer_given = excluded.answer_given, ok = excluded.ok;
  end if;

  if v_correct is false then
    insert into weak_queue (student_id, chapter, idx, misses, next_review, last_seen, technique)
    values (v_student, p_chapter, p_idx, 1, current_date + 1, current_date,
            (select technique_tags[1] from problems where chapter = p_chapter and idx = p_idx))
    on conflict (student_id, chapter, idx) do update
      set misses = weak_queue.misses + 1,
          correct_streak = 0,
          last_seen = current_date,
          next_review = current_date + (case when weak_queue.misses + 1 >= 3 then 7
                                             when weak_queue.misses + 1 = 2 then 3 else 1 end);

    select misses into v_misses from weak_queue
      where student_id = v_student and chapter = p_chapter and idx = p_idx;
    if v_misses >= 3 then
      insert into chapter_progress (student_id, chapter, weak)
      values (v_student, p_chapter, true)
      on conflict (student_id, chapter) do update set weak = true;
    end if;
  elsif v_correct is true then
    select correct_streak into v_streak from weak_queue
      where student_id = v_student and chapter = p_chapter and idx = p_idx;
    if v_streak is not null then
      if v_streak + 1 >= 2 then
        delete from weak_queue where student_id = v_student and chapter = p_chapter and idx = p_idx;
      else
        update weak_queue set correct_streak = v_streak + 1, last_seen = current_date,
                           next_review = current_date + 7
          where student_id = v_student and chapter = p_chapter and idx = p_idx;
      end if;
    end if;
  end if;

  if v_xp > 0 then
    update profiles set xp = coalesce(xp,0) + v_xp, level = 1 + (coalesce(xp,0) + v_xp) / 300
      where student_id = v_student;
  end if;

  -- D7: in a test, nothing is revealed until the test is submitted.
  v_reveal := (p_exam_id is null)
              or exists (select 1 from exam_mocks e
                         where e.id = p_exam_id and e.submitted_at is not null);

  return json_build_object(
    'recorded', true,
    'revealed', v_reveal,
    'correct',   case when v_reveal then v_correct end,
    'needs_manual_mark', case when v_reveal then v_key is null end,
    'xp',        case when v_reveal then v_xp else 0 end,
    'method',    case when v_reveal then v_method end
  );
end $$;

-- Record a session and move the streak. Uses the student's own timezone.
create or replace function record_session(
  p_lane text, p_minutes int, p_status text default 'done', p_note text default null
) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_tz text;
  v_today date;
  v_last date;
  v_streak int;
begin
  if v_student is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  select coalesce(timezone,'Australia/Melbourne'), last_session_date, coalesce(streak_days,0)
    into v_tz, v_last, v_streak
  from profiles where student_id = v_student;

  v_today := (now() at time zone v_tz)::date;

  insert into sessions (student_id, day, lane, minutes, status, note)
  values (v_student, v_today, p_lane, coalesce(p_minutes,0), coalesce(p_status,'done'), p_note);

  if v_last = v_today then
    null;                                             -- already counted today
  elsif v_last = v_today - 1 then
    v_streak := v_streak + 1;
  else
    v_streak := 1;
  end if;

  update profiles set streak_days = v_streak, last_session_date = v_today
    where student_id = v_student;

  return json_build_object('day', v_today, 'streak', v_streak);
end $$;

-- ---------- 14c. which questions belong to which exam (D5) ----------------
create table if not exists exam_map (
  exam text not null,                 -- 'Olympiad book', 'AMC Upper Primary', ...
  chapter int not null,
  idx int not null,
  primary key (exam, chapter, idx),
  foreign key (chapter, idx) references problems(chapter, idx) on delete cascade
);
alter table exam_map enable row level security;
drop policy if exists "read exam_map" on exam_map;
create policy "read exam_map" on exam_map for select to authenticated using (true);

-- everything in the bank belongs to the olympiad paper, for now
insert into exam_map (exam, chapter, idx)
select 'Olympiad book', chapter, idx from problems
on conflict do nothing;

-- ---------- 14d. finish a test, and only then show the answers -----------
create or replace function finish_exam(p_exam_id uuid)
returns json
language plpgsql security definer set search_path = public as $$
declare
  v_student uuid := auth.uid();
  v_row exam_mocks;
  v_score int;
  v_total int;
  v_pct int;
  v_items json;
begin
  if v_student is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;

  select * into v_row from exam_mocks where id = p_exam_id and student_id = v_student;
  if not found then
    raise exception 'no such test for this student';
  end if;

  select count(*) filter (where ok), count(*)
    into v_score, v_total
  from exam_items where exam_id = p_exam_id;

  v_pct := case when coalesce(v_total,0) = 0 then 0 else round(100.0 * v_score / v_total) end;

  update exam_mocks
     set submitted_at = coalesce(submitted_at, now()),
         score = coalesce(v_score,0),
         total = coalesce(v_total,0),
         pct = v_pct,
         marks = coalesce(v_score,0),
         marks_total = coalesce(v_total,0),
         passed = v_pct >= coalesce(pass_bar,70)
   where id = p_exam_id;

  select coalesce(json_agg(json_build_object(
           'chapter', i.chapter, 'idx', i.idx, 'ok', i.ok,
           'answer_given', i.answer_given,
           'answer', a.answer, 'method', a.method) order by i.chapter, i.idx), '[]'::json)
    into v_items
  from exam_items i
  left join problem_answers a on a.chapter = i.chapter and a.idx = i.idx
  where i.exam_id = p_exam_id;

  return json_build_object(
    'score', coalesce(v_score,0),
    'total', coalesce(v_total,0),
    'pct', v_pct,
    'passed', v_pct >= coalesce(v_row.pass_bar,70),
    'items', v_items
  );
end $$;

-- ---------- 15. views for the board --------------------------------------
create or replace view v_chapter_map with (security_invoker = on) as
  select c.n as chapter, c.title, c.tier, c.pages, c.examples, c.practice,
         m.student_id,
         coalesce(m.quiz_best,0) as quiz_best,
         coalesce(m.weak,false) as weak,
         coalesce(m.examples_reviewed,false) as examples_reviewed,
         coalesce(att.n,0) as attempts_made,
         case when coalesce(m.weak,false) then 'needs_work'
              when coalesce(m.quiz_best,0) >= 80 then 'mastered'
              when coalesce(m.quiz_best,0) > 0 then 'cleared'
              when coalesce(att.n,0) > 0 then 'in_progress'
              else 'not_started' end as status
  from chapters c
  left join chapter_progress m on m.chapter = c.n
  left join lateral (
    select count(*) as n from attempts a
    where a.chapter = c.n
      and a.student_id = coalesce(m.student_id, (select auth.uid()))
  ) att on true;

create or replace view v_weak_techniques as
  select r.student_id,
         coalesce(r.technique, 'chapter ' || r.chapter) as technique,
         count(*) as open_items,
         sum(r.misses) as misses,
         min(r.next_review) as next_due
  from weak_queue r
  group by r.student_id, 2;

create or replace view v_due_reviews as
  select r.student_id, r.chapter, r.idx, r.misses, r.next_review,
         p.prompt, p.difficulty
  from weak_queue r join problems p on p.chapter = r.chapter and p.idx = r.idx
  where r.next_review <= current_date;

create or replace view v_mock_trend as
  select student_id, kind, scope, score, total, pct, minutes, taken_at
  from exam_mocks order by taken_at;

-- ---------- 16. exam readiness: is the uploaded content enough? (D5) ------
-- One row per exam. Reads from the bank, the attempt log and the weak queue,
-- so it answers "have we uploaded enough, and has he done enough of it" for
-- the child and the parent in the same words.
create or replace view v_exam_readiness with (security_invoker = on) as
  with per_q as (
    select chapter, idx,
           count(*) as tries,
           count(*) filter (where ok) as ok_count
    from attempts
    where student_id = (select auth.uid())
    group by chapter, idx
  ),
  open_w as (
    select chapter, idx from weak_queue where student_id = (select auth.uid())
  )
  select m.exam,
         count(*) as items,
         count(pq.tries) as practised,
         count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) as mastered,
         case when count(*) = 0 then 0
              else round(100.0 * count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) / count(*))
         end as pct_mastered,
         case when count(*) = 0 then 'no_content'
              when count(*) < 30 then 'thin'
              when count(pq.tries) < 0.4 * count(*) then 'too_early'
              when round(100.0 * count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) / count(*)) >= 80
                then 'ready'
              else 'in_progress' end as verdict,
         case when count(*) = 0
                then 'No questions uploaded for this exam yet.'
              when count(*) < 30
                then 'Only ' || count(*) || ' questions uploaded. More content is needed before this can be judged.'
              when count(pq.tries) < 0.4 * count(*)
                then count(pq.tries) || ' of ' || count(*) || ' practised so far. Too early to say — keep going.'
              when round(100.0 * count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null) / count(*)) >= 80
                then count(*) || ' questions uploaded, ' || count(pq.tries) || ' practised, '
                     || count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null)
                     || ' mastered. The content is enough.'
              else count(*) || ' questions uploaded, ' || count(pq.tries) || ' practised, '
                     || count(*) filter (where coalesce(pq.ok_count,0) > 0 and w.idx is null)
                     || ' mastered. Keep going; more practice needed before this is judged.'
         end as message
  from exam_map m
  left join per_q pq on pq.chapter = m.chapter and pq.idx = m.idx
  left join open_w w  on w.chapter = m.chapter and w.idx = m.idx
  group by m.exam;
