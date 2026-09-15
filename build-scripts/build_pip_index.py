#!/usr/bin/env python3
"""Generate a PEP 503 compliant Simple Index for pip from a directory of wheels.

Usage:
    python3 build_pip_index.py \
        --wheel-dir /path/to/wheels \
        --output-dir /path/to/dist_pages \
        --repo r-xue/casa6-dev \
        --release-tag build-2026.09.15
"""

import argparse
import hashlib
import html
import os
import re
import sys
from pathlib import Path


def compute_sha256(filepath: Path) -> str:
    h = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def normalize_package_name(name: str) -> str:
    """PEP 503 package name normalization (lowercase, runs of [._-] replaced by '-')."""
    return re.sub(r'[-_.]+', '-', name).lower()


def parse_wheel_filename(filename: str) -> tuple[str | None, str | None]:
    """Parse a standard wheel filename.

    Expected format:
    {distribution}-{version}(-{build_tag})?-{python_tag}-{abi_tag}-{platform_tag}.whl
    """
    m = re.match(
        r"^([A-Za-z0-9_]+)-([A-Za-z0-9.+_]+)(?:-([0-9][A-Za-z0-9._]*))?-(.+?)-(.+?)-(.+?)\.whl$",
        filename,
    )
    if not m:
        return None, None
    return m.group(1), m.group(2)


def parse_existing_project_index(index_file: Path) -> dict:
    """Extract existing wheel entries from an existing index.html."""
    entries = {}
    if not index_file.is_file():
        return entries

    content = index_file.read_text(encoding='utf-8')
    # Match <a href="URL">FILENAME</a>
    pattern = re.compile(r'<a\s+href="([^"]+)"[^>]*>([^<]+)</a>')
    for m in pattern.finditer(content):
        href = m.group(1)
        name = m.group(2).strip()
        entries[name] = href
    return entries


def generate_project_html(project_name: str, wheels: dict) -> str:
    """Generate HTML content for /simple/<project>/index.html."""
    lines = [
        '<!DOCTYPE html>',
        '<html>',
        '  <head>',
        '    <meta name="pypi:repository-version" content="1.0">',
        f'    <title>Links for {html.escape(project_name)}</title>',
        '  </head>',
        '  <body>',
        f'    <h1>Links for {html.escape(project_name)}</h1>',
    ]

    # Sort by filename descending (newest first)
    for fname in sorted(wheels.keys(), reverse=True):
        href = wheels[fname]
        lines.append(f'    <a href="{html.escape(href)}">{html.escape(fname)}</a><br/>')

    lines.extend([
        '  </body>',
        '</html>',
        '',
    ])
    return '\n'.join(lines)


def generate_root_simple_html(projects: list) -> str:
    """Generate HTML content for /simple/index.html."""
    lines = [
        '<!DOCTYPE html>',
        '<html>',
        '  <head>',
        '    <meta name="pypi:repository-version" content="1.0">',
        '    <title>Simple Index</title>',
        '  </head>',
        '  <body>',
        '    <h1>Simple Index</h1>',
    ]
    for proj in sorted(projects):
        lines.append(f'    <a href="{html.escape(proj)}/">{html.escape(proj)}</a><br/>')
    lines.extend([
        '  </body>',
        '</html>',
        '',
    ])
    return '\n'.join(lines)


def generate_landing_html(projects: list, repo: str) -> str:
    """Generate a clean user landing page at /index.html with pip install instructions."""
    lines = [
        '<!DOCTYPE html>',
        '<html lang="en">',
        '<head>',
        '  <meta charset="utf-8">',
        '  <meta name="viewport" content="width=device-width, initial-scale=1">',
        f'  <title>CASA6 Binary Wheels ({html.escape(repo)})</title>',
        '  <style>',
        "    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; max-width: 860px; margin: 40px auto; padding: 0 20px; line-height: 1.6; color: #24292e; }",
        '    pre { background: #f6f8fa; padding: 16px; border-radius: 6px; overflow-x: auto; border: 1px solid #e1e4e8; }',
        "    code { font-family: SFMono-Regular, Consolas, 'Liberation Mono', Menlo, monospace; font-size: 85%; }",
        '    a { color: #0366d6; text-decoration: none; }',
        '    a:hover { text-decoration: underline; }',
        '    .card { border: 1px solid #e1e4e8; border-radius: 6px; padding: 16px; margin: 20px 0; }',
        '  </style>',
        '</head>',
        '<body>',
        '  <h1>CASA6 Self-Contained Binary Wheels</h1>',
        f'  <p>Automated standalone Python 3.12 wheel builds for <code>casatools</code> and <code>casatasks</code> from <a href="https://github.com/{html.escape(repo)}">{html.escape(repo)}</a>.</p>',
        '  <div class="card">',
        '    <h2>🚀 Quick Installation</h2>',
        '    <p>Install the latest standalone wheels directly via standard <code>pip</code> without Conda or Pixi:</p>',
        f'    <pre><code>pip install --extra-index-url https://{html.escape(repo.split("/")[0])}.github.io/{html.escape(repo.split("/")[-1])}/simple/ casatools casatasks</code></pre>',
        '    <p><em>(Pip will automatically inspect your host platform and pick either Linux x86_64 or macOS ARM64).</em></p>',
        '  </div>',
        '  <h2>📦 Available Packages</h2>',
        '  <ul>',
    ]
    for proj in sorted(projects):
        lines.append(f'    <li><a href="simple/{html.escape(proj)}/"><strong>{html.escape(proj)}</strong></a></li>')
    lines.extend([
        '  </ul>',
        '  <p>Simple repository index: <a href="simple/"><code>/simple/</code></a></p>',
        '</body>',
        '</html>',
        '',
    ])
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description='Build PEP 503 Simple Index for pip')
    parser.add_argument('--wheel-dir', required=True, help='Directory containing .whl files')
    parser.add_argument('--output-dir', required=True, help='Output directory for generated HTML')
    parser.add_argument(
        '--repo', default=os.environ.get('GITHUB_REPOSITORY', 'r-xue/casa6-dev'), help='GitHub repository (owner/name)'
    )
    parser.add_argument('--release-tag', default='', help='GitHub Release tag (for direct download links)')
    parser.add_argument('--base-url', default='', help='Custom base URL for wheels (defaults to GitHub Release assets)')
    args = parser.parse_args()

    wheel_dir = Path(args.wheel_dir)
    output_dir = Path(args.output_dir)
    simple_dir = output_dir / 'simple'
    simple_dir.mkdir(parents=True, exist_ok=True)

    # Determine URL prefix
    if args.base_url:
        base_url = args.base_url.rstrip('/') + '/'
    elif args.release_tag:
        base_url = f'https://github.com/{args.repo}/releases/download/{args.release_tag}/'
    else:
        base_url = ''

    # Group incoming wheels by normalized package name
    incoming_wheels = {}
    for whl_path in wheel_dir.glob('*.whl'):
        pkg_raw, _ = parse_wheel_filename(whl_path.name)
        if not pkg_raw:
            print(f"Warning: could not parse wheel name '{whl_path.name}', skipping.")
            continue
        norm_pkg = normalize_package_name(pkg_raw)
        sha256 = compute_sha256(whl_path)

        url = f'{base_url}{whl_path.name}#sha256={sha256}' if base_url else f'{whl_path.name}#sha256={sha256}'
        incoming_wheels.setdefault(norm_pkg, {})[whl_path.name] = url
        print(f'Discovered: {whl_path.name} -> {norm_pkg}')

    # Discover all projects (both incoming and previously existing in output_dir)
    all_projects = set(incoming_wheels.keys())
    for existing_proj_dir in simple_dir.iterdir():
        if existing_proj_dir.is_dir() and (existing_proj_dir / 'index.html').is_file():
            all_projects.add(existing_proj_dir.name)

    if not all_projects:
        print('No wheels found and no existing projects. Exiting.')
        return 0

    # For each project, merge existing entries and write updated index.html
    for proj in all_projects:
        proj_dir = simple_dir / proj
        proj_dir.mkdir(parents=True, exist_ok=True)
        proj_index_file = proj_dir / 'index.html'

        # Load existing entries
        merged = parse_existing_project_index(proj_index_file)
        # Update with incoming wheels
        if proj in incoming_wheels:
            merged.update(incoming_wheels[proj])

        html_content = generate_project_html(proj, merged)
        proj_index_file.write_text(html_content, encoding='utf-8')
        print(f'Wrote {len(merged)} links to {proj_index_file}')

    # Write root /simple/index.html
    root_simple_file = simple_dir / 'index.html'
    root_simple_file.write_text(generate_root_simple_html(sorted(all_projects)), encoding='utf-8')
    print(f'Wrote simple index with {len(all_projects)} projects to {root_simple_file}')

    # Write landing page /index.html
    landing_file = output_dir / 'index.html'
    landing_file.write_text(generate_landing_html(sorted(all_projects), args.repo), encoding='utf-8')
    print(f'Wrote landing page to {landing_file}')

    return 0


if __name__ == '__main__':
    sys.exit(main())
