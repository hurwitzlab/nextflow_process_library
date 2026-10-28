# 2026-10-28
Author: sweavs111

- Split `NOTEBOOK.md` into one file per entry under `notebook/`
  (`YYYY-MM-DD_<short-slug>.md`), with the rules and entry format in `notebook/README.md`.
  Entry bodies were moved unchanged; each file gets a `# date` heading and an `Author:` line
  taken from `git blame`. Checked that the concatenated bodies match the old file line for line.
- Why: every entry was appended to the end of the same file, so any two branches that each
  added an entry conflicted. This happened when merging `main` into `test_suite`, PR #2.
  New files never conflict.
- Updated the `/notebook` skill to write a new file instead of appending, and the README's
  "Working on this repo" section to match.
- Next: after this merges, merge `main` into `test_suite`. That gives one expected
  modify/delete conflict on `NOTEBOOK.md`; resolve it by moving test_suite's 2026-10-15 and
  2026-10-19 entries into their own files. Any other branch that edits `NOTEBOOK.md` will hit
  the same conflict.
