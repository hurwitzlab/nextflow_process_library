#!/usr/bin/env python3
"""Build the container catalog and the Hazel container config from the BRC image repository.

Usage (from the repo root):  python3 conf/make_containers.py

Writes:
  conf/container_catalog.tsv    one row per (container param, image version); every
                                params.container__<tool> used under modules/ appears, with an
                                empty local_image when no image exists on Hazel. public_uri is
                                the registry source; locally built images instead get a
                                custom_build link to their .def recipe directory
  conf/containers_hazel.config  params.container__<tool> = <default image>, for pipelines on
                                Hazel to includeConfig (and for the nf-test suite)

Images are matched to a container param by exact name — the BRC modulefile directory the image
belongs to, or the image's own name with registry prefix/version stripped when it has no
modulefile. Never by substring. Params whose name differs from the image name go in OVERRIDES.
The default version is the newest one unless OVERRIDES pins another.

custom_build links follow the BRC infra site (hurwitzlab/brc-infra-site, parse_modules.py
--custom-build-lookup): a locally built image's tool name is matched case-insensitively and exactly
against the tools/ directories of CUSTOM_BUILD_REPO (one GitHub API call), linking the directory
rather than the .def file, since .def filenames aren't consistently named. Unlike the site, a failed
lookup aborts the run, so regenerating offline can't silently drop links from the committed catalog.
"""
import json
import re
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
IMAGES = Path("/usr/local/usrapps/brc/brc_modules/images")
MODULEFILES = Path("/usr/local/usrapps/brc/brc_modules/modules")
CATALOG = REPO / "conf" / "container_catalog.tsv"
CONFIG = REPO / "conf" / "containers_hazel.config"
CUSTOM_BUILD_REPO, CUSTOM_BUILD_PATH, CUSTOM_BUILD_BRANCH = "sweavs111/custom_container_module", "tools", "main"

# param -> {"image": <image name key>, "default": <pinned version>, "note": ...}
# "image": None means no image on Hazel is valid for this param.
OVERRIDES = {
    "bbmap":        {"image": "bbtools", "note": "bbmap is part of bbtools"},
    "bbmerge":      {"image": "bbtools", "note": "bbmerge is part of bbtools"},
    "bbnorm":       {"image": "bbtools", "note": "bbnorm is part of bbtools"},
    "gatk":         {"image": "gatk4"},
    "mummer":       {"image": "mummer4"},
    "checkm":       {"image": "checkm-genome", "note": "checkm, not checkm2"},
    "checkv":       {"image": "phorager-checkv-bundle", "note": "checkv is provided by the phorager bundle"},
    "eggnogmapper": {"image": "eggnog-mapper", "default": "2.1.13", "note": "2.1.13 pinned over the 3.0.0 beta"},
    "virfinder":    {"image": None, "note": "DeepVirFinder is a different tool; do not use"},
    "genomad_filterviral":    {"image": None, "note": "R script step; left unset for now"},
    "genomad_viralselection": {"image": None, "note": "R script step; left unset for now"},
}
IGNORE_PARAMS = {"TOOLNAME"}  # TEMPLATE.nf placeholder


def version_key(v):
    # Drop a leading "v" before a digit ("v3.1b2" -> "3.1b2"): otherwise "v" sorts after the empty
    # string a plain "3.4" starts with, and the v-prefixed version always looks newest
    v = re.sub(r"^v(?=\d)", "", v)
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", v)]


def name_and_version(image):
    """Fallback for images with no modulefile: 'quay.io_biocontainers_x:1.2--h0.sif' -> ('x', '1.2')."""
    stem = re.sub(r"^(quay\.io_biocontainers_|biocontainers_|staphb_)", "", image.removesuffix(".sif")).lower()
    if ":" in stem:
        name, version = stem.split(":", 1)
        return name, version.split("--")[0]
    m = re.match(r"(.+?)[-.]((?:git-|v?\d).*)$", stem)
    return (m.group(1), m.group(2)) if m else (stem, "")


def read_modulefiles():
    """image filename -> (module name, version, uri), from each modulefile's `set` lines."""
    found = {}
    for mf in MODULEFILES.glob("*/*"):
        if not mf.is_file():
            continue
        sets = dict(re.findall(r'^set\s+(\w+)\s+"([^"]*)"', mf.read_text(errors="replace"), re.M))
        if "image" in sets:
            found[sets["image"]] = (mf.parent.name.lower(), sets.get("version", mf.name), sets.get("uri", ""))
    return found


def fetch_custom_build_dirs():
    """{lowercased name: actual name} for each directory under CUSTOM_BUILD_REPO's tools/."""
    url = (f"https://api.github.com/repos/{CUSTOM_BUILD_REPO}/contents/{CUSTOM_BUILD_PATH}"
           f"?ref={CUSTOM_BUILD_BRANCH}")
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json",
                                               "User-Agent": "nextflow-process-library"})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"ERROR: could not list {url} for custom_build links: {exc}")
    if not isinstance(data, list):
        raise SystemExit(f"ERROR: unexpected response listing {url}: {data!r}")
    return {item["name"].lower(): item["name"] for item in data if item.get("type") == "dir"}


def custom_build_link(name, build_dirs):
    match = build_dirs.get(name.lower())
    if match is None:
        return ""
    return f"https://github.com/{CUSTOM_BUILD_REPO}/tree/{CUSTOM_BUILD_BRANCH}/{CUSTOM_BUILD_PATH}/{match}"


def module_params():
    params = set()
    for nf in (REPO / "modules").rglob("*.nf"):
        params.update(re.findall(r"params\.container__(\w+)", nf.read_text()))
    return sorted(params - IGNORE_PARAMS)


def main():
    modulefiles = read_modulefiles()
    build_dirs = fetch_custom_build_dirs()
    by_name = {}  # image name key -> [(version, image, public_uri, custom_build)]
    for img in sorted(p.name for p in IMAGES.glob("*.sif")):
        if img in modulefiles:
            name, version, uri = modulefiles[img]
        else:
            (name, version), uri = name_and_version(img), ""
        build = ""
        if not uri.startswith("docker://"):  # local builds record their own .sif path as the uri
            uri, build = "", custom_build_link(name, build_dirs)
        by_name.setdefault(name, []).append((version, img, uri, build))

    rows, defaults = [], {}
    for param in module_params():
        ov = OVERRIDES.get(param, {})
        key = ov.get("image", param.lower())
        versions = sorted(by_name.get(key, []), key=lambda r: version_key(r[0])) if key else []
        note = ov.get("note", "")
        if not versions:
            rows.append((param, "", "", "", "", "", note))
            continue
        default = ov.get("default", versions[-1][0])
        if default not in [v[0] for v in versions]:
            raise SystemExit(f"ERROR: pinned default {param}={default} not among {[v[0] for v in versions]}")
        for version, img, uri, build in versions:
            is_default = version == default
            rows.append((param, version, "yes" if is_default else "no", str(IMAGES / img), uri, build, note))
            if is_default:
                defaults[param] = str(IMAGES / img)

    with CATALOG.open("w") as fh:
        fh.write("param\tversion\tdefault\tlocal_image\tpublic_uri\tcustom_build\tnote\n")
        fh.writelines("\t".join(r) + "\n" for r in rows)

    missing = [r[0] for r in rows if not r[3]]
    width = max(len(p) for p in defaults) + len("container__")
    with CONFIG.open("w") as fh:
        fh.write("// conf/containers_hazel.config\n"
                 "// GENERATED by conf/make_containers.py from conf/container_catalog.tsv. Do not edit by hand.\n"
                 "// Default (newest unless pinned) local image for each container param on Hazel.\n"
                 "params {\n")
        for param, path in sorted(defaults.items()):
            fh.write(f'    {"container__" + param:<{width}} = "{path}"\n')
        fh.write("\n    // No image on Hazel yet (define these yourself if you use the process):\n")
        fh.writelines(f"    //   container__{p}\n" for p in missing)
        fh.write("}\n")

    print(f"{len(defaults)} params with an image ({len(rows) - len(missing)} catalog versions), "
          f"{len(missing)} without: {CATALOG.relative_to(REPO)}, {CONFIG.relative_to(REPO)}")


if __name__ == "__main__":
    main()
