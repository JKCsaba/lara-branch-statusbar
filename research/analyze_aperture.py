#!/usr/bin/env python3
"""Stage 4: read-only System Aperture CONTAINER/LAYOUT evidence, iOS 18.4 22E240.

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
    # Exact method implementation addresses from the 22E240 class dumps.
    # Targets are SpringBoard's container geometry and expanded-layout policy,
    # NOT the visual rotation transform. All operations are read-only.
    ('container_layout', 'SBSystemApertureContainerView layoutSubviews', 0x1d83deb88, 280),
    ('container_set_frame', 'SBSystemApertureContainerView setFrame:', 0x1d84044dc, 170),
    ('container_set_bounds', 'SBSystemApertureContainerView setBounds:', 0x1d83e0708, 150),
    ('container_set_center', 'SBSystemApertureContainerView setCenter:', 0x1d83e07d8, 150),
    ('container_clipping', 'SBSystemApertureContainerView setContentClippingEnabled:', 0x1d834d714, 150),
    ('container_hit_testing', 'SBSystemApertureContainerView _layoutHitTestViewWithBounds:', 0x1d83df080, 165),
    ('container_content_transform', 'SBSystemApertureContainerView _setContentViewTransform:elementViewControllerInterfaceOrientation:', 0x1d83b35f0, 175),
    ('container_transform_update', 'SBSystemApertureContainerView _updateContentViewTransformImmediately', 0x1d83b34cc, 140),
    ('controller_min_size_by_orientation', 'SBSystemApertureViewController _preferredMinSizeForCustomLayout:elementInterfaceOrientation:', 0x1d87d5530, 185),
    ('controller_preferred_outsets', 'SBSystemApertureViewController preferredEdgeOutsetsForLayoutMode:suggestedOutsets:maximumOutsets:forTargetWithOverrider:isDefaultValue:', 0x1d87d0ca4, 260),
    ('controller_set_layout_mode', 'SBSystemApertureViewController setLayoutMode:reason:forTargetWithOverrider:', 0x1d87d07cc, 180),
    ('controller_host_outsets', 'SBSystemApertureViewController _hostSuggestedOutsetsForElement:', 0x1d87d122c, 180),
    ('controller_layout_overrider', 'SBSystemApertureViewController _layoutSpecifyingOverriderForContainerView:', 0x1d87cf6b0, 145),
    ('controller_statusbar_avoidance', 'SBSystemApertureViewController _updateStatusBarAvoidanceFrameWithAnimationSettings:', 0x1d87d4c64, 160),
]

CLASSES = [
    'SBSystemApertureContainerView',
    'SBSystemApertureViewController',
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
    lines=['iOS 18.4 System Aperture Stage 4 container and layout extraction (read-only)',
           f'Successful commands: {good}/{len(items)}',
           'EXTRACTION SUCCEEDED DOES NOT MEAN THE EXPANSION ROOT CAUSE IS CONFIRMED.',
           *[f"  {r['label']}: exit={r['exit_code']} ({r['elapsed_seconds']}s) {r['file']}" for r in items]]
    summary='\n'.join(lines)+'\n'
    (ns.out/'SUMMARY.txt').write_text(summary,encoding='utf-8')
    (ns.out/'SUMMARY_STAGE4.txt').write_text(summary,encoding='utf-8')
    print(summary,flush=True)
    if good != len(items):
        raise SystemExit(f'Stage 4 evidence incomplete: {good}/{len(items)} commands succeeded; inspect logs and artifact')

if __name__ == '__main__':
    main()
