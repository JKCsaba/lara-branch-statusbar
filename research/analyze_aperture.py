#!/usr/bin/env python3
"""Read-only second-pass disassembly of iPhone 12 iOS 18.4 (22E240) SpringBoard.

Requires the exact Apple dyld shared cache extracted by the existing GitHub Actions workflow.
Never interacts with Lara, any connected iPhone, or SpringBoard processes.
"""
import argparse
import json
import pathlib
import subprocess
import sys
import time

IMAGE = '/System/Library/PrivateFrameworks/SpringBoard.framework/SpringBoard'
# Addresses established from the class-dump evidence for 22E240, not runtime ASLR addresses.
TARGETS = [
    ('window_autorotates', '0x1d8ba82cc', 100),
    ('rotation_context_init', '0x1d88508a0', 140),
    ('rotation_context_affine', '0x1d885093c', 100),
    ('orientation_authority', '0x1d83b3720', 32),
    ('active_element_orientation_getter', '0x1d83df634', 45),
    ('system_aperture_scene_orientation', '0x1d8ba8cac', 200),
    ('host_orientation_full', '0x1d87d5ebc', 360),
    ('element_orientation_full', '0x1d87d61a4', 440),
    ('transform_builder_target', '0x1de3c11e0', 45),
    ('supported_interface_orientations', '0x1d87cae70', 80),
    ('portrait_container_frame', '0x1d87cfe30', 120),
]


def run_command(command, destination, timeout=40):
    started = time.monotonic()
    status = 'unknown'
    with destination.open('w', encoding='utf-8') as stream:
        stream.write('CMD: ' + ' '.join(command) + '\n\n')
        stream.flush()
        try:
            p = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                               timeout=timeout, check=False)
            status = f'exit={p.returncode}'
        except subprocess.TimeoutExpired:
            status = f'timeout={timeout}s'
        except OSError as exc:
            status = f'error={exc}'
        stream.write('\nRESULT: ' + status + '\n')
    return status, round(time.monotonic() - started, 2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dsc', type=pathlib.Path, required=True)
    ap.add_argument('--out', type=pathlib.Path, required=True)
    ap.add_argument('--disass-limit', type=int, default=14)
    opts = ap.parse_args()
    if not opts.dsc.is_file() or opts.dsc.name != 'dyld_shared_cache_arm64e' or '22E240' not in str(opts.dsc):
        ap.error('Must use the exact iOS 18.4 22E240 arm64e shared cache from iPhone13,2')
    opts.out.mkdir(parents=True, exist_ok=True)
    results = []

    # Capture the doubles used by +transformForRotationToInterfaceOrientation:.
    extra = [
        ('orientation_constants_landscape', ['ipsw', 'dyld', 'dump', str(opts.dsc), '0x1d8d381d0', '--bytes', '--size', '16']),
        ('orientation_constants_default', ['ipsw', 'dyld', 'dump', str(opts.dsc), '0x1d8d38078', '--bytes', '--size', '8']),
        ('rotating_content_superclass', ['ipsw', 'class-dump', str(opts.dsc), IMAGE, '--class', '^_SBSystemApertureContainerViewContentView$', '--re', '-V']),
    ]
    for name, cmd in extra:
        print(f'[metadata] {name}: starting', flush=True)
        status, seconds = run_command(cmd, opts.out / f'{name}.txt', 45)
        results.append({'name': name, 'status': status, 'seconds': seconds, 'file': f'{name}.txt'})
        print(f'[metadata] {name}: {status} ({seconds}s)', flush=True)

    targets = TARGETS[:max(0, min(len(TARGETS), opts.disass_limit))]
    for i, (name, addr, count) in enumerate(targets, 1):
        filename = f'stage2_{i:02}_{name}.txt'
        cmd = ['ipsw', 'dyld', 'disass', str(opts.dsc), '--vaddr', addr,
               '--quiet', '--count', str(count)]
        print(f'[{i}/{len(targets)}] {name} at {addr}: starting', flush=True)
        status, seconds = run_command(cmd, opts.out / filename, timeout=45)
        results.append({'name': name, 'vaddr': addr, 'count': count,
                        'status': status, 'seconds': seconds, 'file': filename})
        (opts.out/'stage2_results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
        print(f'[{i}/{len(targets)}] {name}: {status} ({seconds}s)', flush=True)

    summary = '\n'.join(f"{r['name']} : {r['status']} in {r['seconds']}s -> {r['file']}" for r in results) + '\n'
    (opts.out/'SUMMARY_STAGE2.txt').write_text(summary, encoding='utf-8')
    # Existing GitHub workflow prints SUMMARY.txt; preserve its output contract.
    (opts.out/'SUMMARY.txt').write_text(summary, encoding='utf-8')
    print(summary, flush=True)
    return 0 if any(r['status'] == 'exit=0' and r['name'] in {t[0] for t in targets} for r in results) else 1

if __name__ == '__main__':
    sys.exit(main())
