# 2026-09-30
Author: sweavs111

- Restructured `modules/` so every tool lives in its own directory:
  `modules/<tool>.nf` → `modules/<tool>/<tool>.nf` (96 files, via `git mv` so
  history follows). Kept the tool name as the filename rather than nf-core's
  `main.nf`. Left in place: `TEMPLATE.nf` (a copy-paste starting point, not a
  tool), `bbmap.nf copy` (still the known stray file), and `modules/dev/`.
  Updated the README's `include` example and `ls`/`grep` discovery commands to
  `modules/*/*.nf`, and the File layout rule in `modules/CLAUDE.md`. Old paths
  in earlier notebook entries were left as-is (append-only log).
- Checked for in-repo breakage: none. No module `include`s another, and the
  only `../` paths in module code (`vibrant.nf`, `mmseqs2.nf`) are relative to
  the task work dir at runtime, not the `.nf` file's location.
- **Breaking for consuming pipelines:** any pipeline that `include`s a module
  by its old path fails at parse time once it picks up this change, until the
  path gains the `<tool>/` segment. Pipelines pinned to an earlier commit are
  unaffected. Consumer repos haven't been audited yet.
- Also removed the 3 tracked `.DS_Store` files (root, `modules/`,
  `modules/dev/`) and added `.DS_Store` to `.gitignore`.
- Opened PR #1 (branch `restructure-modules-into-dirs`). Next: update
  consuming pipelines' `include` paths after merge; decide on `bbmap.nf copy`,
  whether `TEMPLATE.nf` gets a directory, and whether the README commands
  should exclude `dev/` (`modules/*/*.nf` now matches it too).
