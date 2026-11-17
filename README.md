# Atharv's Olympiad Quest

A coaching programme for the 2027 AMC Upper Primary (3–5 August 2027) and APSMO
Division J (May–September 2027), built on Terry Chew's *Maths Olympiad (Advanced)*,
24 chapters, walked in the book's own order.

The book content lives here. The state — what he has done, what he missed, what is
due — lives in Supabase. The page here only reads.

---

## How to use it, week by week

**Every session starts with the plan, not with a question.** `TIMETABLE_v3.md` says
what today is: which chapter, how many questions, and whether it is a quest day, a
drill day or a test day. The board shows the same thing on screen.

1. **Open the board** (`quest_board.html`). It shows today's lane, his XP and streak,
   the 24-chapter map, and the three things he keeps getting wrong.
2. **Do the session.** The chapter's worked examples first, then the practice
   questions in order. He works on paper; the book has the diagrams.
3. **Mark it.** Each answer goes through `submit_answer()` — one call per question.
   It returns right or wrong, the XP, and the method. On the thirteen construction
   and proof questions it returns `needs_manual_mark`, and you mark it by eye with
   `mark_attempt()`.
4. **If he gets four right in a row with no hints**, stop the chapter and take the
   quiz early. Eighty percent or better means the rest is skipped, not done.
5. **Saturday is the test.** A chapter quiz, or from 22 January a full AMC paper at
   60 minutes and 135 marks.
6. **Read the diagnosis, not the score.** `v_weak_techniques` names the topics, and
   the question numbers behind them. That is what next week's drill is built from.

### What the parent looks at

The Parent tab on the same page: the readiness verdict per exam, the weakest
techniques with question ids, recent tests, and the countdown to the next real exam.
Once a week, ask one question: *which technique is he losing the most marks to?*
If it is the same one two weeks running, it is a gap, not a slip.

---

## What is where

```
TIMETABLE_v3.md              the week-by-week plan, 17 Nov 2026 to 14 Feb 2027
quest_board.html             the board — static, reads Supabase, writes nothing
architecture.png             how the pieces fit together
supabase/functions/coach-work/index.ts   the photo-of-working coach

migrations/
  001_schema.sql             the original schema, as first uploaded
  002_quest_upgrade.sql      append-only attempts, answer key walled off, guardian
                             access, prototype table names, server-side scoring
  003_seed_extras.sql        tiers, difficulty, technique tags, pages, 109 examples
  004_cron.sql               pg_cron and the nightly tick
  005_answer_keys.sql        12 keys set by hand, 13 marked manual on purpose
  006_marking.sql            normalisation, mark_mode, mark_attempt()
  007_working.sql            storage bucket and working_reviews
  008_plan_seed.sql          plan_days keyed by seq, and the plan as data

```

The study guide, the original timetable and the design review are **not** in this
repository. They live in a private repository — they contain the book's question bank
and the family's details, and nothing here reads them at run time.

Run the migrations in order, once, on an empty project. All of them are safe to
re-run; `002` is the only one that changes anything irreversibly, because it drops
`problems.answer` after copying it into `problem_answers`.

---

## The stack, and why

| Piece | Runs where | Why there |
|---|---|---|
| Book content, questions, answers | Supabase Postgres | answers must not be readable by the child's browser |
| Marking, XP, quiz scoring | Supabase (SECURITY DEFINER functions) | a browser can be edited; a score cannot be trusted from one |
| Photo of rough work | Supabase Storage + Edge Function | the model key cannot live in a static page |
| Nightly tick (missed days, streaks, milestones) | pg_cron | no server to run it, and it must fire whether or not anyone opens the app |
| The board | GitHub Pages | static, no secrets, reads through the publishable key and RLS |
| The plan, the migrations, the documents | this repository | so the database can be rebuilt and the plan can be read without a login |

Row-level security is the whole security model. The publishable key in the page is
public by design; the only thing standing between it and his data is RLS. That is
why answers live in a table with no policy for the client at all.

---

## The live board

Published at **https://akshaybangalorekar.github.io/atharv-olympiad-quest/**
(from the `gh-pages` branch, which holds only `index.html`).

To make it work, the publishable key has to be on line 2 of that file:
edit `index.html` on the `gh-pages` branch in the GitHub web editor, replace
`PASTE_PUBLISHABLE_KEY_HERE`, and commit. Nothing else needs changing, and the
same edit goes in `quest_board.html` on `main` if you want the local copy to work.

## Running the board

`quest_board.html` has two lines to edit at the top:

```js
const SUPABASE_URL = "https://<project-ref>.supabase.co";
const SUPABASE_KEY = "<the publishable key, sb_publishable_...>";
```

Open it in a browser. It works from the file system; it also works from GitHub
Pages, which is the point. Never put the `service_role` key in this file.

Accounts: Atharv, Pooja and Akshay each sign up with email and password in the
Supabase dashboard (Authentication → Users → Add user), then run the linking SQL at
the bottom of `008_plan_seed.sql` so the parents can read his data.

## The photo coach

`coach-work.ts` is the Edge Function behind "look at my working". It takes a photo,
reads the question and the book's method from the database, and replies with what is
right, the exact slip, one alternative method, one check question and a request to
explain it back. It never states the final answer.

```bash
supabase functions deploy coach-work --project-ref <project-ref>
supabase secrets set ANTHROPIC_API_KEY=<key> --project-ref <project-ref>
```

The key goes in as a Supabase secret, never in this repository and never in the page.

---

## Status, honestly

Working: the schema, the 288 questions and 109 examples, marking, XP, the weak
queue, the nightly job, the plan, the board, the readiness indicator.

Not yet done: the accounts do not exist, so `plan_days` is empty and the board shows
its empty states; the photo coach is deployed but untested against the live model
until the API key is set; AAS, Edutest, ICAS and ELMS content is not uploaded, and
the readiness view will say `thin` for them until it is.
