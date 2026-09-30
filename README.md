# Nextflow Process Library

Database of all the Hurwitz lab's Nextflow processes — reusable tool wrappers
(`process` blocks) shared across every lab pipeline, so a bug fix or new
container path only has to happen in one place.

This repo holds processes only. It has no pipeline of its own, no `workflow {}`
entry point, and no config — it's a library that pipeline repos (like
[`viral_inference_benchmark`](https://github.com/hurwitzlab/viral_inference_benchmark))
include from.

## Using these processes in a pipeline

Clone this repo **as a sibling** of the pipeline repo that uses it, under the
same parent directory:

```
some_parent_dir/
  your_pipeline_repo/
  nextflow_modules/
```

Then `include` a process by relative path from wherever your subworkflow or
workflow file lives, e.g. from `your_pipeline_repo/nextflow_pipeline/subworkflows/`:

```groovy
include { genomad } from '../../../nextflow_process_library/modules/genomad/genomad.nf'
```

Nextflow resolves `include` paths as literal strings at parse time — they
can't be driven by a config variable — so the exact number of `../` depends
on how deep your including file is. Count directory levels up to the shared
parent, then down into `nextflow_process_library/modules/`.

**Pinning:** cloning this repo gives you whatever commit is on `main` at
clone time. If you need a pipeline to keep working against a known-good
version regardless of later changes here, checkout a specific tag/commit in
your local clone rather than tracking `main`:

```bash
cd nextflow_process_library
git checkout <tag-or-commit>
```

## What a process expects from the pipeline that includes it

Every process reads its container, output directory, and tool options from
`params.*` — it never defines them itself. The consuming pipeline's own
`.config` (or a config it includes) must define, for each process it uses:

- `params.container__<tool>` — path to the tool's container image
- `params.<tool>_outdir` — where terminal output gets published (if the
  process has a `publishDir`)
- `params.<tool>_<option>` — any tool-specific options the process references

The consuming pipeline is also expected to define `withLabel:process_single`,
`withLabel:process_low`, `withLabel:process_medium`, and
`withLabel:process_high` resource selectors (e.g. in its own
`conf/base.config`) — every process tags its process with one of these labels,
but resource amounts are the pipeline's call, not this repo's.

If a process you need references a param your pipeline's config doesn't have
yet, add it — see the process's file for the exact `params.*` names it expects.

## Repo layout: `modules/` vs `modules/dev/`

- **`modules/`** — the reviewed set. If a pipeline can `include` it today,
  it lives here.
- **`modules/dev/`** — staging for processes converted or written but not yet
  reconciled against what's already in `modules/`. Nothing here is
  guaranteed to work, and nothing here should be `include`d by a pipeline.

Promoting a process out of `dev/`:

1. Check whether `modules/` already has a file for the same tool.
2. **No existing file** — move it up as a new file.
3. **Existing file, different process name(s)** — merge your process(es)
   into the existing file as additional `process` blocks (one file per
   tool, per `modules/CLAUDE.md`), then remove the file from `dev/`.
4. **Existing file, same process name** — a real collision. Don't just pick
   one and delete the other; check whether they're actually redundant or
   cover different cases, and reconcile by hand (rename, merge logic, or
   consolidate) before promoting either.

## Available Processes

This repo holds 100+ tool processes as of this writing — a hand-maintained
table here goes stale within a day given how often processes get added or
promoted from `modules/dev/`. To see what's actually available:

```bash
ls modules/*/*.nf                                   # every process file
grep -h '^process\|^ process' modules/*/*.nf | sort  # every process name, across all files
```

Some tools have multiple processes in one file (e.g. `bbmap.nf` has
`bbwrap` + `pileup`; `samtools.nf` has several BAM/SAM conversion steps) —
see **File layout** in `modules/CLAUDE.md` for why.

## Adding a new process

1. Read `modules/CLAUDE.md` — house rules for file layout, process block
   structure, shell interpolation style, and `params.*` naming.
2. Copy `modules/TEMPLATE.nf` as a starting point.
3. Work through the checklist at the bottom of `CLAUDE.md` before considering
   it done.
4. In your PR description, list every `params.*` name the new process
   references, so pipeline maintainers know what to add to their own config.

## Contributing

This repo gets edited concurrently — by different lab members, and often by
more than one Claude Code session at once. That's exactly how a real
process-name collision (two processes both defining a process called
`vibrant`) happened here. Before adding a process:

1. Check `modules/*/*.nf` for an existing file with the same tool name — don't
   assume a name is free just because your own source material doesn't
   mention an existing module.
2. If it already exists, add your process(es) to that file instead of
   creating a duplicate (see **Repo layout** above for the full promotion
   decision tree if you're coming from `modules/dev/`).
3. Follow `modules/CLAUDE.md` and `modules/TEMPLATE.nf` either way (see
   **Adding a new module** above).

## Known issues

- `modules/bbmap.nf copy` — a stray file (content differs from `bbmap.nf`,
  looks like an accidental Finder duplicate). Should be deleted or explained;
  it isn't a real process.
- `modules/dev/phamb.nf` and `modules/dev/viralverify.nf` — both completely
  empty (0 bytes), placeholders with no `process` block at all.
- `modules/dev/virfinder.nf` — unbalanced braces (8 `{` vs. 7 `}`), so its
  final `process` block never closes.

None of the three `dev/` files above should be promoted or `include`d as-is.

## Working on this repo

Whatever you change here — a process, `CLAUDE.md`, this README, anything —
**record it in `NOTEBOOK.md` before you're done**, not just in the commit
message. The commit says *what* changed; the notebook says *why* and *what
happened* (results, errors, decisions, flags for whoever picks this up next),
which is exactly the context a diff can't carry on its own.

### Lab notebook conventions

`NOTEBOOK.md` at the repo root is a chronological, append-only log of work
sessions on this repo — one dated entry per session, covering what was done,
what happened (concrete results/errors, not a diff restatement), and the
decision or next step. Never edit or reorder past entries; always append.

If you use Claude Code, this convention is checked in as a project skill at
`.claude/skills/notebook/` — anyone who clones this repo gets the same
`/notebook` behavior automatically, no setup needed. If you don't use Claude
Code, follow the header format documented at the top of `NOTEBOOK.md` itself.

### A prompt to record your session

If you're using Claude Code (or a similar assistant) here, `/notebook` alone
does this. If you're prompting a general assistant, or want to be explicit
about what you expect, something like this works:

```
Before we wrap up, review what we changed in this session and append one
dated entry to NOTEBOOK.md at the repo root, following the format in its own
header. Cover:
- what was done/tried
- what happened — concrete results, errors, numbers, not a restatement of
  the diff
- any decision made or flags left for whoever works on this next

If today's date already has an entry, add to it rather than starting a new
heading. Never edit or reorder any past entry — only append.
```
