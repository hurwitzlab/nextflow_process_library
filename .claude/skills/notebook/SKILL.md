---
name: notebook
description: Write a dated entry in this project's notebook/ directory summarizing recent work, debugging, or experiment results. Use when the user asks to log/journal progress, update the lab notebook, or invokes /notebook — typically before a commit or at the end of a work session.
---

# Lab notebook entry

`notebook/` at the project root is a chronological lab notebook with one Markdown file per
entry (see `notebook/README.md` for the rules and entry format). Your job: write one well-formed
entry covering what happened since the user's last entry, as a new file.

## Steps

0. If `notebook/` doesn't exist at the project root yet, create it with a `README.md` holding
   the rules and entry format below, then continue to step 1 as normal (there will be no prior
   entries).

1. List `notebook/` and read the most recent entries, especially the user's own last one
   (match its `Author:` line against `git config user.name`), to find where to pick up.
2. Reconstruct what happened since then:
   - If this is a git repo (`git rev-parse --is-inside-work-tree` succeeds): `git log --oneline`
     since the last entry's approximate date, and `git diff` / `git status` for anything
     currently uncommitted. Skip this entirely if it's not a git repo — don't error on it.
   - The current conversation's own context (what was debugged, decided, tried, and the
     outcome — numbers, errors, results — not just "edited file X").
3. Write ONE entry dated today (`YYYY-MM-DD`, use the actual current date — check it via the
   session context or `date +%F`, never guess). If the user already has an entry file for today
   (same date, same `Author:`), add to it instead of creating a second file.
4. Name the new file `notebook/YYYY-MM-DD_<short-slug>.md`, where the slug is a few lowercase
   hyphenated words naming the main topic. Make sure the name isn't already taken. Use this
   format:

   ```markdown
   # YYYY-MM-DD
   Author: <git config user.name>

   - What was done / tried
   - What happened (concrete results, errors, numbers — not a diff restatement)
   - Decision or next step
   ```

   Skip anything that's just visible in `git log`/`git diff` with no added context — the
   notebook is for the *why* and *outcome*, not a diff restatement.
5. Never edit, rename or delete anyone else's entry, or any past entry other than the user's own
   entry from today.

Keep it tight: a few bullets, not a report. If nothing notable happened since the last entry,
say so rather than inventing content.
