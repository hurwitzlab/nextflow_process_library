#!/usr/bin/env python3
"""Build the container catalog and the Hazel container config from the BRC image repository.

Usage (from the repo root):  python3 conf/make_containers.py

Writes:
  conf/container_catalog.tsv    one row per (container param, image version); every
                                params.container__<tool> used under modules/ appears, with an
                                empty local_image when no image exists on Hazel
  conf/containers_hazel.config  params.container__<tool> = <default image>, for pipelines on
                                Hazel to includeConfig (and for the nf-test suite)

Images are matched to a container param by exact name — the BRC modulefile directory the image
belongs to, or the image's own name with registry prefix/version stripped when it has no
modulefile. Never by substring. Params whose name differs from the image name go in OVERRIDES.
The default version is the newest one unless OVERRIDES pins another.
"""
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
IMAGES = Path("/usr/local/usrapps/brc/brc_modules/images")
MODULEFILES = Path("/usr/local/usrapps/brc/brc_modules/modules")
CATALOG = REPO / "conf" / "container_catalog.tsv"
CONFIG = REPO / "conf" / "containers_hazel.config"

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


def module_params():
    params = set()
    for nf in (REPO / "modules").rglob("*.nf"):
        params.update(re.findall(r"params\.container__(\w+)", nf.read_text()))
    return sorted(params - IGNORE_PARAMS)


def main():
    modulefiles = read_modulefiles()
    by_name = {}  # image name key -> [(version, image, public_uri)]
    for img in sorted(p.name for p in IMAGES.glob("*.sif")):
        if img in modulefiles:
            name, version, uri = modulefiles[img]
        else:
            (name, version), uri = name_and_version(img), ""
        if not uri.startswith("docker://"):  # local builds record their own .sif path as the uri
            uri = ""
        by_name.setdefault(name, []).append((version, img, uri))

    rows, defaults = [], {}
    for param in module_params():
        ov = OVERRIDES.get(param, {})
        key = ov.get("image", param.lower())
        versions = sorted(by_name.get(key, []), key=lambda r: version_key(r[0])) if key else []
        note = ov.get("note", "")
        if not versions:
            rows.append((param, "", "", "", "", note))
            continue
        default = ov.get("default", versions[-1][0])
        if default not in [v for v, _, _ in versions]:
            raise SystemExit(f"ERROR: pinned default {param}={default} not among {[v for v, _, _ in versions]}")
        for version, img, uri in versions:
            is_default = version == default
            rows.append((param, version, "yes" if is_default else "no", str(IMAGES / img), uri, note))
            if is_default:
                defaults[param] = str(IMAGES / img)

    with CATALOG.open("w") as fh:
        fh.write("param\tversion\tdefault\tlocal_image\tpublic_uri\tnote\n")
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
