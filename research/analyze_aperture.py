#!/usr/bin/env python3
"""Read-only analysis of the exact iOS 18.4 SpringBoard framework in an extracted DSC.

This does not touch the device or Lara. Designed for GitHub macOS runner.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys
import traceback

IMAGE = '/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard'
CLASSES = [
    '_SBSystemApertureContainerViewRotatingContentView',
    'SBSystemApertureViewController',
    'SBSystemApertureController',
    'SBSystemApertureWindow',
    'SBSystemApertureElementOrientationAuthority',
    'SBSystemApertureViewControllerRotationTransitionContext',
    'SBSystemApertureCaptureVisibilityShimViewController',
    'SBSystemApertureCurtainViewController',
]
PROTOCOL = '.*(SystemAperture.*Orientation|Orientation.*SystemAperture).*'
PATTERN = re.compile(r'orientation|rotat|transform|transition|expan|layout|aperture|supportedinterface', re.I)
ADDR = re.compile(r'0x[0-9a-fA-F]{7,}')


def execute(args, path: pathlib.Path, timeout=600):
    try:
        p = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                           text=True, encoding='utf-8', errors='replace', timeout=timeout)
        data = f"$ {' '.join(args)}\nexit_code={p.returncode}\n\nSTDOUT\n{p.stdout}\n\nSTDERR\n{p.stderr}\n"
        path.write_text(data, encoding='utf-8')
        return p.returncode, p.stdout
    except Exception as exc:
        path.write_text(f"$ {' '.join(args)}\nERROR: {exc}\n{traceback.format_exc()}", encoding='utf-8')
        return -1, ''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dsc', type=pathlib.Path, required=True)
    ap.add_argument('--out', type=pathlib.Path, required=True)
    ap.add_argument('--disass-limit', type=int, default=10)
    ns = ap.parse_args()
    ns.out.mkdir(parents=True, exist_ok=True)
    report = {'image': IMAGE, 'dsc': str(ns.dsc), 'classes': {}, 'methods': [], 'disassembly': []}
    if not ns.dsc.is_file():
        raise FileNotFoundError(ns.dsc)

    # Resolve exact image before class introspection; do not guess from a short dylib name.
    execute(['ipsw', 'dyld', 'image', str(ns.dsc), IMAGE], ns.out/'springboard_image.txt', 240)
    collected = []
    for cls in CLASSES:
        outfile = ns.out/f'class_{cls}.txt'
        cmd = ['ipsw', 'class-dump', str(ns.dsc), IMAGE,
               '--class', '^'+re.escape(cls)+'$', '--re', '-V']
        code, body = execute(cmd, outfile, 300)
        report['classes'][cls] = {'exit_code': code, 'file': outfile.name,
                                  'has_method_addresses': bool(ADDR.search(body))}
        lines = body.splitlines()
        for i, line in enumerate(lines):
            if PATTERN.search(line) and re.match(r'\s*[+-]\s*\(', line):
                # In RE mode addresses may appear on the declaration itself or a nearby comment.
                candidates = [line, *lines[max(0, i-2):i]]
                found = next((ADDR.search(txt).group(0) for txt in candidates if ADDR.search(txt)), None)
                if found:
                    collected.append((cls, line.strip(), found))

    execute(['ipsw', 'class-dump', str(ns.dsc), IMAGE,
             '--proto', PROTOCOL, '--re', '-V'], ns.out/'orientation_protocols.txt', 300)
    report['methods'] = [dict(class_name=cls, signature=sig, vaddr=addr)
                         for cls, sig, addr in collected]
    report['methods'].sort(key=lambda m: (
        0 if 'RotatingContentView' in m['class_name'] else 1,
        0 if 'orient' in m['signature'].lower() else 1,
        m['class_name'], m['signature']))

    # Verified SpringBoard iOS 18.4 / 22E240 methods.
    preferred = [
        '0x1d83b36d0', # Rotation transform
        '0x1d87d5ebc', # Host orientation change
        '0x1d87d61a4', # Element orientation update
        '0x1d83b3720', # Element orientation authority
        '0x1d83df634', # Active element orientation
        '0x1d8ba82cc', # Window autorotation
        '0x1d88508a0', # Rotation context initialization
        '0x1d885093c', # Affine transform
        '0x1d8ba8cac', # Window scene orientation update
        '0x1d87cfe30', # Portrait container frame
        '0x1d87cae70', # Supported orientations
        '0x1d87d5530', # Preferred minimum size
        '0x1d87d56b0', # Custom layout Y offset
        '0x1d8869914', # Orientation preferences
    ]
    report['methods'].sort(key=lambda m: (
        preferred.index(m['vaddr']) if m['vaddr'] in preferred else 999,
        m['class_name'], m['signature']))
    seen = set()
    for item in report['methods']:
        addr = item['vaddr'].lower()
        if addr in seen or len(seen) >= ns.disass_limit:
            continue
        seen.add(addr)
        outfile = ns.out/f"disass_{len(seen):02d}_{addr}.txt"
        cmd = ['ipsw', 'dyld', 'disass', str(ns.dsc), '--vaddr', addr]
        rc, _ = execute(cmd, outfile, 600)
        report['disassembly'].append({**item, 'exit_code': rc, 'file': outfile.name})

    (ns.out/'method_inventory.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    summary = [
        'iOS 18.4 SpringBoard: offline inspection (NOT a validated hook)',
        f'Cache: {ns.dsc}',
        'Class results:',
        *[f"  {name}: exit={rec['exit_code']}, method_addr={rec['has_method_addresses']}" for name, rec in report['classes'].items()],
        'Candidate methods:',
        *[f"  {m['vaddr']} [{m['class_name']}] {m['signature']}" for m in report['methods']],
        'Disassembly attempts:',
        *[f"  {d['vaddr']} -> {d['file']} (exit={d['exit_code']})" for d in report['disassembly']],
    ]
    (ns.out/'SUMMARY.txt').write_text('\n'.join(summary)+'\n', encoding='utf-8')
    print('\n'.join(summary)[:12000])


if __name__ == '__main__':
    main()
