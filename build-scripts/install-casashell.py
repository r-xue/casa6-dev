#!/usr/bin/env python3
"""
Automatically detects locally built/installed casatasks version and installs
the closest matching casashell release from the NRAO PyPI index without pulling
unwanted binary dependencies.
"""

from __future__ import annotations

import glob
import importlib
import os
import re
import subprocess
import sys
import sysconfig
from typing import Optional


def get_casatasks_version() -> Optional[str]:
    """Detect casatasks version from active environment or built wheel artifact."""
    try:
        casatasks = importlib.import_module("casatasks")
        if hasattr(casatasks, "version_string"):
            return str(casatasks.version_string())
    except Exception:
        pass

    wheels = sorted(glob.glob("src/casa6/casatasks/dist/casatasks-*.whl"), reverse=True)
    if wheels:
        m = re.search(r"casatasks-([0-9]+(?:\.[0-9]+)+)", wheels[0])
        if m:
            return m.group(1)
    return None


def ensure_casalith_marker(version: Optional[str] = None) -> None:
    """Create a dummy casalith marker in site-packages to enable casashell MPI dispatch."""
    marker_version = version or "6.7.7.7"
    marker_header = "# Marker package to enable casashell built-in MPI server dispatch"
    target_dirs: list[str] = []
    purelib = sysconfig.get_path("purelib")
    platlib = sysconfig.get_path("platlib")
    if purelib:
        target_dirs.append(purelib)
    if platlib and platlib not in target_dirs:
        target_dirs.append(platlib)

    for p in target_dirs:
        if not os.path.exists(p):
            continue
        if os.path.isdir(os.path.join(p, "casalith")):
            print(f"Found existing casalith package in {p}; skipping marker.")
            return
        marker = os.path.join(p, "casalith.py")
        if os.path.exists(marker):
            try:
                with open(marker, encoding="utf-8") as f:
                    if marker_header not in f.read():
                        print(f"Found non-marker {marker}; skipping.")
                        return
            except OSError:
                pass
        try:
            with open(marker, "w", encoding="utf-8") as f:
                f.write(f'{marker_header}\n__version__ = "{marker_version}"\n')
            print(f"Created casalith marker in {marker} (version {marker_version})")
            break
        except OSError as e:
            print(f"Could not create casalith marker in {marker}: {e}")


def build_casashell_specs(version: Optional[str]) -> list[str]:
    """Build ordered pip requirement specs from most-specific to broadest fallback."""
    if not version:
        return ["casashell"]

    specs = [f"casashell=={version}"]
    m = re.match(r"^(\d+)\.(\d+)(?:\.(\d+))?", version)
    if m:
        major, minor, patch = m.group(1), int(m.group(2)), m.group(3)
        next_minor = f"{major}.{minor + 1}.0"
        if patch is not None:
            specs.append(f"casashell>={major}.{minor}.{patch},<{next_minor}")
        specs.append(f"casashell>={major}.{minor},<{next_minor}")
    specs.append("casashell")
    return list(dict.fromkeys(specs))


def main() -> int:
    """Find and install the closest matching casashell release from NRAO PyPI."""
    version = get_casatasks_version()
    index_url = "https://casa-pip.nrao.edu/repository/pypi-group/simple"

    if not version:
        print("Could not detect casatasks version. Installing latest casashell...")
    else:
        print(f"Detected local casatasks version: {version}")
    specs = build_casashell_specs(version)

    for spec in specs:
        print(f"Checking NRAO index for: {spec}...")
        cmd = [
            sys.executable,
            "-m",
            "pip",
            "install",
            spec,
            "--no-deps",
            "--extra-index-url",
            index_url,
        ]
        res = subprocess.run(cmd, check=False)
        if res.returncode == 0:
            print(f"Successfully matched and installed casashell ({spec})!")
            ensure_casalith_marker(version)
            return 0

    print("Failed to find any matching casashell.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

