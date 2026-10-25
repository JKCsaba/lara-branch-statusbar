#!/usr/bin/env python3
"""Stage 3: read-only System Aperture GEOMETRY evidence, exact iOS 18.4 22E240.

Existing GH workflow calls: --dsc PATH --out DIRECTORY --disass-limit N
This script never attaches to a device, injects into SpringBoard, or patches code.
"""
import argparse
import json
import pathlib
import re
import subprocess
import time
import traceback

IMAGE = '/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard'
# Addresses independently recovered from exact SpringBoard.class-dump --method addresses
# in first iOS 18.4 (22E240) evidence artifact. Don't apply to another build.
TARGETS = [
    ('default_island_frame', 'SBSystemApertureController defaultIslandFrameInCoordinateSpace:', 0x1d8ba9bc0, 180),
    ('container_center_get', 'SBSystemApertureViewController containerParentCenter', 0x1d8335958, 75),
    ('container_center_set', 'SBSystemApertureViewController setContainerParentCenter:', 0x1d87ce564, 145),
    ('layout_subviews', 'SBSystemApertureViewController viewWillLayoutSubviews', 0x1d87cf2a0, 185),
    ('max_container_outsets', 'SBSystemApertureViewController _maximumContainerViewOutsetsInBounds:inLayoutMode:', 0x1d87cfca4, 185),
    ('custom_layout_y', 'SBSystemApertureViewController _yOffsetForCustomLayout:', 0x1d87d56b0, 145),
    ('content_size_outsets', 'SBSystemApertureViewController edgeOutsetsForSize:', 0x1d87d1448, 160),
    ('adjunct_layout_bounds', 'SBSystemApertureViewController _boundsForAdjunctContainerViewWithPreferredEdgeOutsets:layoutDirection:', 0x1d87cfef0, 160),
    ('container_frame_changed', 'SBSystemApertureViewController systemApertureContainerView:didChangeFrame:', 0x1d87d2988, 110),
    ('container_center_changed', 'SBSystemApertureViewController systemApertureContainerView:didChangeCenter:', 0x1d83e09a4, 100),
    ('sensor_region_frame', 'SBSystemApertureViewController _frameForSensorRegionInBounds:', 0x1d83df698, 120),
    ('container_parent_updates', 'SBSystemApertureViewController _handleContainerParentUpdatesFromPreferences:context:', 0x1d834a9c4, 160),
    ('container_and_element_updates', 'SBSystemApertureViewController _handleContainerAndElementUpdatesFromPreferences:orderedElementViewControllers:context:', 0x1d834b0a4, 140),
]

CLASSES = [
    'SBSystemApertureContainerView',
    'SBSystemApertureWindowScene',
    'SBSystemApertureContainerViewGeometryObserver',
    'SBSystemApertureContainerViewDelegate',
]


def run_capture(label, args, out_path, timeout=70):
    t0 = time.monotonic()
    print(f'START {label}: {" ".join(args)}', flush=True)
    try:
        cp = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            errors='replace', timeout=timeout)
        content = f'CMD: {" ".join(args)}\nEXIT: {cp.returncode}\n' + cp.stdout + '\nSTDERR:\n' + cp.stderr
        rc, error = cp.returncode, None
    except subprocess.TimeoutExpired as exc:
        rc, error = 124, f'TIMEOUT after {timeout}s: {exc}'
        def btotext(b):
            return b.decode('utf-8', 'replace') if isinstance(b, bytes) else (b or '')
        content = f'CMD: {" ".join(args)}\n{error}\nPARTIAL STDOUT:\n' + btotext(exc.stdout) + '\nPARTIAL STDERR:\n' + btotext(exc.stderr)
    except Exception as exc:
        rc, error = 125, f'{type(exc).__name__}: {exc}'
        content = f'CMD: {" ".join(args)}\n{error}\n{traceback.format_exc()}'
    out_path.write_text(content, encoding='utf-8')
    elapsed = round(time.monotonic() - t0, 2)
    print(f'END   {label}: exit={rc} elapsed={elapsed}s file={out_path.name}', flush=True)
    return {'label': label, 'exit_code': rc, 'elapsed_seconds': elapsed, 'file': out_path.name, 'error': error}


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--dsc', type=pathlib.Path, required=True)
    p.add_argument('--out', type=pathlib.Path, required=True)
    p.add_argument('--disass-limit', type=int, default=14, help='Existing workflow compatibility; bounded by TARGETS')
    ns = p.parse_args()
    ns.out.mkdir(parents=True, exist_ok=True)
    if not ns.dsc.is_file():
        raise FileNotFoundError(ns.dsc)
    items = []
    for name in CLASSES:
        op = 'proto' if 'Observer' in name or 'Delegate' in name else 'class'
        outfile = ns.out / ('geometry_' + re.sub(r'\W+', '_', name) + '.txt')
        args = ['ipsw', 'class-dump', str(ns.dsc), IMAGE, '--'+op, '^'+re.escape(name)+'$', '--re', '-V']
        items.append(run_capture(name, args, outfile, timeout=60))
    for short, full, addr, count in TARGETS[:max(0, min(ns.disass_limit, len(TARGETS)))]:
        outfile = ns.out / f'geometry_{short}_0x{addr:x}.txt'
        args = ['ipsw','dyld','disass',str(ns.dsc),'--vaddr',f'0x{addr:x}','--quiet','--count',str(count)]
        items.append(run_capture(full, args, outfile, timeout=70))
    (ns.out/'geometry_manifest.json').write_text(json.dumps({'firmware':'iOS 18.4 22E240 / iPhone13,2',
        'image':IMAGE,'items':items},indent=2),encoding='utf-8')
    good=sum(x['exit_code']==0 for x in items)
    lines=['iOS 18.4 System Aperture geometry extraction (read-only)',
           f'Successful commands: {good}/{len(items)}',
           'EXTRACTION SUCCEEDED DOES NOT MEAN THE EXPANSION ROOT CAUSE IS CONFIRMED.',
           *[f"  {r['label']}: exit={r['exit_code']} ({r['elapsed_seconds']}s) {r['file']}" for r in items]]
    summary='\n'.join(lines)+'\n'
    (ns.out/'SUMMARY.txt').write_text(summary,encoding='utf-8')
    (ns.out/'SUMMARY_STAGE3.txt').write_text(summary,encoding='utf-8')
    print(summary,flush=True)

if __name__ == '__main__':
    main()
