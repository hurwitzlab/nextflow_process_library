# 2026-10-07
Author: sweavs111

- Added `templates/base.config`, a copy-from starting point that defines all
  six labels modules use (`process_single`/`low`/`medium`/`high`,
  `publish_final`/`publish_intermediate`). Until now the README told pipelines
  to define them but gave nothing to copy, and the only working definitions
  lived in one lab pipeline (`hurwitzlab/merys_nf_pipelines`,
  `nextflow_pipeline/conf/base.config`). Prompted by the BRC Infrastructure
  site's Nextflow tab, which needed somewhere neutral to point for what the
  labels mean instead of one pipeline's own settings.
- Tier numbers, retry policy (retry once on exit 130-145/104, all requests
  scaled by `task.attempt`) and the `resolvePublishDir` dispatch were carried
  over from that pipeline unchanged, as starting values. Header comments say
  to copy rather than `includeConfig` it from here, and to tune from
  trace/`seff` results.
- Checked it parses: `nextflow config` (26.04.3, BRC module) on a stub
  `nextflow.config` that includes it resolves every tier and both publish
  blocks. Not exercised by a real pipeline run.
- **Doc fix — outdir naming:** the label-based `publishDir` looks up
  `params.<process name>_outdir` (the last segment of `task.process`), not
  `params.<tool>_outdir` as the README and `modules/CLAUDE.md` said. 106 of
  the 129 label-published processes in `modules/` have a process name that
  differs from their file's tool name (e.g. `bbmap.nf`'s `pileup` →
  `params.pileup_outdir`), and the reference pipeline already defines them
  that way (`pileup_outdir`, `bbduk_outdir`, `filter_viral_contigs_outdir`).
  Corrected both docs; in-module `publishDir` processes are unchanged (they
  use whatever param their own line names).
- Flag: `publish_mode_intermediate` defaults to `'symlink'`, which points into
  the work dir — published links break if `cleanup = true` (the reference
  pipeline sets it) or work/ sits on 30-day-purged scratch. Kept as the
  default to match existing behavior, with a warning comment; worth deciding
  whether the template should default to `'copy'`.
- Next: open a PR; once merged, the BRC site's `parse_nextflow.py` can read
  the tier values from this file instead of anyone hand-copying them.
