#!/usr/bin/env python3
"""test_ledger.py -- track which nf-test files need re-running.

Each test file (modules/<tool>/tests/<name>.nf.test) gets a pass record next to it
(<name>.nf.test.pass) when it passes. The record holds a fingerprint: a hash of everything
the test depends on. A test is STALE when it has no record or its fingerprint has changed.

What goes into a test's fingerprint:
  test       the .nf.test file itself
  snap       its .nf.test.snap (if any)
  process    the text of the process under test, and of any process run in a setup block --
             only that process's block, so editing one process in a 13-process module file
             doesn't make the other 12 tests stale
  shared     the module file's code outside process blocks (top-level defs, params, includes;
             comments and blank lines ignored), for each module file used
  fixture    every file under ${baseDir}/... or ${moduleDir}/... the test references
             (directories are hashed recursively)
  container  the resolved params.container__<tool> image for each process used
  config     tests/nextflow.config, nf-test.config, and the tool versions run_tests.sh loads

Content hashes, not timestamps: commit dates survive rebases and merges unchanged, local
edits have no commit date, and file mtimes are reset by clones and checkouts.

Usage (from anywhere in the repo):
  test_ledger.py status [--why] [PATH ...]   table of tests and their state
  test_ledger.py stale  [--all] [PATH ...]   print stale test files, one per line
  test_ledger.py check  [PATH ...]           exit 1 if any test is stale (for CI)
  test_ledger.py record TEST ...             write pass records (run_tests.sh --stale calls this)
PATH may be a test file or a directory to search; default is the whole repo.
"""

import argparse
import datetime
import getpass
import glob
import hashlib
import json
import os
import re
import subprocess
import sys

RECORD_SUFFIX = ".pass"
RECORD_VERSION = 1

REPO = subprocess.run(
    ["git", "-C", os.path.dirname(os.path.abspath(__file__)), "rev-parse", "--show-toplevel"],
    check=True, capture_output=True, text=True).stdout.strip()

# A top-level statement in a module file: what ends the previous process block
# (a few modules indent the `process` line by a space)
TOP_LEVEL = re.compile(r"^(\s*process\s+\w+\s*\{|(workflow|def|include|params|nextflow)\b)")
PROCESS_START = re.compile(r"^\s*process\s+(\w+)")
FIXTURE_REF = re.compile(r"\$\{?(baseDir|projectDir|moduleDir)\}?(/[^\"'\s)]*)")
CONTAINER_PARAM = re.compile(r"params\.(container__\w+)")
CONTAINER_VALUE = re.compile(r"^\s*(?:params\.)?(container__\w+)\s*=\s*[\"']([^\"']*)[\"']")
SETUP_RUN = re.compile(r"\brun\(\s*[\"'](\w+)[\"']\s*\)\s*\{(?:\s*script\s+[\"']([^\"']+)[\"'])?")


def rel(path):
    return os.path.relpath(path, REPO)


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_path(path):
    """Hash a file, or a directory's files (names + contents) recursively; None if missing."""
    if os.path.isfile(path):
        with open(path, "rb") as fh:
            return sha256_bytes(fh.read())
    if os.path.isdir(path):
        h = hashlib.sha256()
        for root, dirs, files in os.walk(path):
            dirs.sort()
            for name in sorted(files):
                full = os.path.join(root, name)
                h.update(os.path.relpath(full, path).encode() + b"\0")
                h.update(sha256_path(full).encode() + b"\0")
        return h.hexdigest()
    return None


# ---------------------------------------------------------------- module files

_module_cache = {}


def split_module(script):
    """Return ({process_name: block_text}, shared_text) for a module .nf file."""
    if script in _module_cache:
        return _module_cache[script]
    with open(script) as fh:
        lines = fh.read().splitlines()

    processes, shared, current, block = {}, [], None, []

    def close():
        if current is not None:
            # trailing comments/blank lines after the closing brace belong to the next process
            while block and (not block[-1].strip() or block[-1].lstrip().startswith("//")):
                shared.append(block.pop())
            processes[current] = "\n".join(block)

    for line in lines:
        if TOP_LEVEL.match(line):
            close()
            current, block = None, []
            m = PROCESS_START.match(line)
            if m:
                current, block = m.group(1), [line]
                continue
        (block if current is not None else shared).append(line)
    close()

    # Comments, blank lines and the shebang outside processes don't change behaviour
    text = re.sub(r"/\*.*?\*/", "", "\n".join(shared), flags=re.S)
    code = [l for l in text.splitlines() if l.strip() and not l.lstrip().startswith(("//", "#!"))]
    _module_cache[script] = (processes, "\n".join(code))
    return _module_cache[script]


# ---------------------------------------------------------------- fingerprints

_containers = None


def container_values():
    """params.container__* values as the tests resolve them (Hazel defaults)."""
    global _containers
    if _containers is None:
        _containers = {}
        for cfg in ("conf/containers_hazel.config", "tests/nextflow.config"):
            path = os.path.join(REPO, cfg)
            if os.path.isfile(path):
                with open(path) as fh:
                    for line in fh:
                        m = CONTAINER_VALUE.match(line)
                        if m:
                            _containers[m.group(1)] = m.group(2)
    return _containers


def runner_versions():
    """The `module load` lines in run_tests.sh: bumping Nextflow or nf-test re-tests everything."""
    path = os.path.join(REPO, "tests/run_tests.sh")
    with open(path) as fh:
        return "\n".join(l.strip() for l in fh if l.strip().startswith("module load"))


def components(test):
    """{component: hash} for one test file. Problems are recorded as components too, so a
    broken reference makes the test stale rather than crashing the tool."""
    test_dir = os.path.dirname(test)
    with open(test) as fh:
        text = fh.read()
    comp = {"test": sha256_bytes(text.encode())}

    snap = test + ".snap"
    comp["snap"] = sha256_path(snap) or "none"

    # Process under test, then any processes run in setup blocks
    m_script = re.search(r"^\s*script\s+[\"']([^\"']+)[\"']", text, re.M)
    m_proc = re.search(r"^\s*process\s+[\"'](\w+)[\"']", text, re.M)
    if not (m_script and m_proc):
        comp["error"] = "no top-level script/process in test"
        return comp
    main_script = os.path.normpath(os.path.join(test_dir, m_script.group(1)))
    used = [(main_script, m_proc.group(1))]
    for name, script in SETUP_RUN.findall(text):
        used.append((os.path.normpath(os.path.join(test_dir, script)) if script else main_script, name))

    params = set()
    for script, name in used:
        key = f"{rel(script)}:{name}"
        if not os.path.isfile(script):
            comp[f"process:{key}"] = "MISSING SCRIPT"
            continue
        processes, shared = split_module(script)
        block = processes.get(name)
        comp[f"process:{key}"] = sha256_bytes(block.encode()) if block is not None else "MISSING PROCESS"
        comp[f"shared:{rel(script)}"] = sha256_bytes(shared.encode())
        params.update(CONTAINER_PARAM.findall(block or ""))

    containers = container_values()
    for p in sorted(params):
        comp[f"container:{p}"] = containers.get(p, "UNSET")

    # ${moduleDir} in nf-test is the directory of the script under test
    bases = {"baseDir": REPO, "projectDir": REPO, "moduleDir": os.path.dirname(main_script)}
    for base, sub in sorted(set(FIXTURE_REF.findall(text))):
        pattern = os.path.normpath(bases[base] + sub)
        matches = sorted(glob.glob(pattern)) if any(c in pattern for c in "*?[") else [pattern]
        for path in matches or [pattern]:
            comp[f"fixture:{rel(path)}"] = sha256_path(path) or "MISSING"

    for cfg in ("tests/nextflow.config", "nf-test.config"):
        comp[f"config:{cfg}"] = sha256_path(os.path.join(REPO, cfg)) or "MISSING"
    comp["config:runner_versions"] = sha256_bytes(runner_versions().encode())
    return comp


def fingerprint(comp):
    return sha256_bytes("\n".join(f"{k}={v}" for k, v in sorted(comp.items())).encode())


# ---------------------------------------------------------------- records

def load_record(test):
    try:
        with open(test + RECORD_SUFFIX) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def state(test):
    """(state, reasons, record): state is 'ok', 'stale' or 'new'."""
    comp = components(test)
    rec = load_record(test)
    if rec is None:
        return "new", ["no pass record"], None
    if rec.get("fingerprint") == fingerprint(comp):
        return "ok", [], rec
    old = rec.get("components", {})
    reasons = [f"changed: {k}" for k in sorted(comp) if k in old and old[k] != comp[k]]
    reasons += [f"added: {k}" for k in sorted(comp) if k not in old]
    reasons += [f"removed: {k}" for k in sorted(old) if k not in comp]
    return "stale", reasons or ["fingerprint format changed"], rec


def git(*args):
    r = subprocess.run(["git", "-C", REPO, *args], capture_output=True, text=True)
    return r.stdout.strip()


def record(test):
    comp = components(test)
    if any(v.startswith("MISSING") or k == "error" for k, v in comp.items()):
        bad = [f"{k}={v}" for k, v in comp.items() if v.startswith("MISSING") or k == "error"]
        sys.exit(f"ERROR: not recording {rel(test)}: {', '.join(bad)}")
    rec = {
        "record_version": RECORD_VERSION,
        "fingerprint": fingerprint(comp),
        "passed_at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
        "passed_by": getpass.getuser(),
        "commit": git("rev-parse", "--short", "HEAD"),
        "uncommitted_changes": bool(git("status", "--porcelain", "--untracked-files=no")),
        "slurm_job_id": os.environ.get("SLURM_JOB_ID"),
        "modules_loaded": os.environ.get("LOADEDMODULES"),
        "components": comp,
    }
    with open(test + RECORD_SUFFIX, "w") as fh:
        json.dump(rec, fh, indent=2, sort_keys=False)
        fh.write("\n")
    print(f"recorded {rel(test)}")


# ---------------------------------------------------------------- CLI

def find_tests(paths):
    found = set()
    for p in paths or [REPO]:
        p = os.path.abspath(p)
        if os.path.isfile(p) and p.endswith(".nf.test"):
            found.add(p)
        elif os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = [d for d in dirs if not d.startswith(".") and d != "work"]
                found.update(os.path.join(root, f) for f in files if f.endswith(".nf.test"))
        else:
            sys.exit(f"ERROR: not a test file or directory: {p}")
    return sorted(found)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("status");  s.add_argument("--why", action="store_true"); s.add_argument("paths", nargs="*")
    s = sub.add_parser("stale");   s.add_argument("--all", action="store_true", help="list every test"); s.add_argument("paths", nargs="*")
    s = sub.add_parser("check");   s.add_argument("paths", nargs="*")
    s = sub.add_parser("record");  s.add_argument("paths", nargs="+")
    args = ap.parse_args()

    if args.cmd == "record":
        for t in args.paths:
            if not (os.path.isfile(t) and t.endswith(".nf.test")):
                sys.exit(f"ERROR: not a test file: {t}")
            record(os.path.abspath(t))
        return

    tests = find_tests(args.paths)
    if args.cmd == "stale":
        for t in tests:
            if args.all or state(t)[0] != "ok":
                print(rel(t))
        return

    counts = {"ok": 0, "stale": 0, "new": 0}
    for t in tests:
        st, reasons, rec = state(t)
        counts[st] += 1
        if args.cmd == "status":
            when = rec.get("passed_at", "")[:10] if rec else ""
            print(f"{st:6} {when:10}  {rel(t)}")
            if args.why:
                for r in reasons:
                    print(f"{'':19}{r}")
        elif st != "ok":
            print(f"{st}: {rel(t)}" + (f"  ({'; '.join(reasons)})" if reasons else ""))
    print(f"{len(tests)} tests: {counts['ok']} ok, {counts['stale']} stale, {counts['new']} new",
          file=sys.stderr)
    if args.cmd == "check" and counts["ok"] != len(tests):
        sys.exit(1)


if __name__ == "__main__":
    main()
