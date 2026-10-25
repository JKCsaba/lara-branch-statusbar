#!/usr/bin/env python3
"""Stage 5: iOS 18.4 / iPhone 12 System Aperture orientation HANDOFF research.

Goal: trace host UIInterfaceOrientationPortraitUpsideDown (2) into the Island's
layout/obstruction/animation policy so the entire Island can behave as portrait
(1), while the rest of SpringBoard continues in upside-down portrait.  Visual
CGAffineTransform changes are deliberately NOT the proposed fix.

Offline dyld disassembly only. No iPhone, RemoteCall, SpringBoard mutation or IPA.
Compatible with .github/workflows/springboard-184-research.yml: --dsc, --out,
--disass-limit 14.
"""
from __future__ import annotations
import argparse
import json
import re
import subprocess
import time
import traceback
from pathlib import Path

SPRINGBOARD = '/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard'
# All addresses independently checked against the exact 22E240 class dump.
# No cross-version portability should be assumed.
# Short name, class, selector (without argument types), implementation address, instruction cap
TARGETS = [
 ('host_orientation_entry', 'SBSystemApertureViewController', 'hostOrientationDidChangeTo:withPreviousOrientation:context:', 0x1d87d5ebc, 190),
 ('element_orientation_update', 'SBSystemApertureViewController', '_updateElementOrientationTo:withTransitionCoordinator:', 0x1d87d61a4, 210),
 ('controller_orientation_authority_query', 'SBSystemApertureViewController', 'activeElementInterfaceOrientationForSystemApertureElementOrientationObserver:', 0x1d83b3720, 12),
 ('controller_active_orientation_getter', 'SBSystemApertureViewController', '_activeElementInterfaceOrientation', 0x1d83df634, 28),
 ('container_orientation_authority_query', 'SBSystemApertureContainerView', 'activeElementInterfaceOrientationForSystemApertureElementOrientationObserver:', 0x1d83b3574, 38),
 ('container_orientation_changed', 'SBSystemApertureContainerView', 'elementOrientationDidChangeWithTransitionCoordinator:', 0x1d84b2154, 200),
 ('container_set_orientation_authority', 'SBSystemApertureContainerView', 'setElementOrientationAuthority:', 0x1d83b3448, 38),
 ('container_update_content_orientation', 'SBSystemApertureContainerView', '_updateContentViewTransformImmediately', 0x1d83b34cc, 45),
 ('container_content_transform_and_orientation', 'SBSystemApertureContainerView', '_setContentViewTransform:elementViewControllerInterfaceOrientation:', 0x1d83b35f0, 115),
 ('controller_update_orientation_preferences', 'SBSystemApertureViewController', '_updatePreferencesForReasonOrientation:updates:', 0x1d8869914, 145),
 ('controller_layout_on_orientation', 'SBSystemApertureViewController', 'viewWillLayoutSubviews', 0x1d87cf2a0, 300),
 ('controller_size_for_orientation', 'SBSystemApertureViewController', '_preferredMinSizeForCustomLayout:elementInterfaceOrientation:', 0x1d87d5530, 155),
 ('controller_supported_orientation_mask', 'SBSystemApertureViewController', 'supportedInterfaceOrientations', 0x1d87cae70, 6),
 ('container_sensor_obstruction', 'SBSystemApertureViewController', 'sensorRegionObstructingViewProvider:inContentView:', 0x1d87d1980, 160),
]
CLASSES = ['SBSystemApertureViewController', 'SBSystemApertureContainerView']


def execute(label: str, argv: list[str], out: Path, timeout: int = 70) -> dict:
    start = time.monotonic()
    print(f'START {label}', flush=True)
    try:
        cp = subprocess.run(argv, capture_output=True, text=True, errors='replace', timeout=timeout)
        s = f'CMD: {" ".join(argv)}\nEXIT: {cp.returncode}\n{cp.stdout}\nSTDERR:\n{cp.stderr}'
        code, error = cp.returncode, None
    except subprocess.TimeoutExpired as exc:
        code, error = 124, f'TIMEOUT after {timeout}s'
        def convert(v):
            return v.decode('utf-8', 'replace') if isinstance(v, bytes) else (v or '')
        s = f'CMD: {" ".join(argv)}\n{error}\n{convert(exc.stdout)}\nSTDERR:\n{convert(exc.stderr)}'
    except Exception as exc:
        code, error = 125, f'{type(exc).__name__}: {exc}'
        s = f'CMD: {" ".join(argv)}\n{error}\n{traceback.format_exc()}'
    out.write_text(s, encoding='utf-8')
    dur = round(time.monotonic()-start, 2)
    print(f'END {label} code={code} elapsed={dur}s', flush=True)
    return {'label': label, 'exit_code': code, 'seconds': dur, 'file': out.name, 'error': error}


def validate_dump(class_dump: str, selector: str, addr: int) -> bool:
    """Require address/selector on same metadata entry, not two random hits."""
    for line_no, line in enumerate(class_dump.splitlines()):
        if line.strip() == f'// 0x{addr:x}':
            lines = class_dump.splitlines()[line_no+1:line_no+3]
            for declaration in lines:
                if declaration.lstrip().startswith('- ('):
                    # Strip parameter type text, retaining Objective-C labels.
                    stripped = re.sub(r'\([^)]*\)', '', declaration)
                    parts = selector.split(':')
                    # Method base has to appear; parameter portions may contain nested struct types.
                    if parts[0] in stripped:
                        return True
    return False


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dsc', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--disass-limit', type=int, default=14)
    ns = ap.parse_args()
    if not ns.dsc.is_file():
        raise SystemExit(f'Cache does not exist: {ns.dsc}')
    ns.out.mkdir(parents=True, exist_ok=True)
    outputs: list[dict] = []
    dump_text: dict[str, str] = {}
    for cls in CLASSES:
        destination = ns.out / f'orientation_class_{cls}.txt'
        argv = ['ipsw', 'class-dump', str(ns.dsc), SPRINGBOARD, '--class', '^'+re.escape(cls)+'$', '--re', '-V']
        outputs.append(execute('class '+cls, argv, destination, timeout=80))
        dump_text[cls] = destination.read_text(encoding='utf-8')
    chosen = TARGETS[:min(max(ns.disass_limit, 0), len(TARGETS))]
    unverified = []
    for label, cls, selector, addr, count in chosen:
        if not validate_dump(dump_text[cls], selector, addr):
            unverified.append(f'{cls} {selector} at 0x{addr:x}')
            print(f'UNVERIFIED class-dump match: {unverified[-1]}', flush=True)
            continue
        dest = ns.out / f'orientation_{label}_0x{addr:x}.txt'
        argv = ['ipsw', 'dyld', 'disass', str(ns.dsc), '--vaddr', f'0x{addr:x}', '--quiet', '--count', str(count)]
        outputs.append(execute(label, argv, dest, timeout=80))
    manifest = {
        'target': 'iPhone13,2 / 18.4 22E240',
        'objective': 'Stop upside-down orientation from affecting System Aperture layout, obstruction and animation; NOT a visual rotation tweak',
        'method_boundaries': '--count is an instruction count; may spill into later functions',
        'unverified_class_dump_entries': unverified,
        'methods': [{'label':l,'class':c,'selector':s,'address':f'0x{a:x}','instruction_cap':n} for l,c,s,a,n in chosen],
        'commands': outputs,
    }
    (ns.out / 'orientation_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    good = sum(x['exit_code'] == 0 for x in outputs)
    summary = '\n'.join([
        'Stage 5 — System Aperture orientation handoff (OFFLINE, READ-ONLY)',
        'iPhone 12 (iPhone13,2), iOS 18.4 build 22E240',
        f'Commands succeeded: {good}/{len(outputs)}',
        f'Class-dump address mismatches: {len(unverified)}',
        'Objective: entire Island uses normal-portrait INTERNAL orientation (1) while phone remains upside-down (2).',
        'No visual-rotation-only workaround. No device changes. Not a proven fix.',
        'Check transitions 2->1, origin host orientation, container authority, and geometry/animation consumers.',
        'Caution: disassembly --count may spill across method boundaries; use class dumps to delimit methods.',
        '', *[f"{v['label']}: exit={v['exit_code']} {v['file']}" for v in outputs], '',
    ])
    (ns.out / 'SUMMARY.txt').write_text(summary, encoding='utf-8')
    (ns.out / 'SUMMARY_ORIENTATION_STAGE5.txt').write_text(summary, encoding='utf-8')
    print(summary, flush=True)
    if good != len(outputs) or unverified:
        raise SystemExit('Incomplete Stage 5 orientation evidence. Inspect artifact.')

if __name__ == '__main__':
    main()
