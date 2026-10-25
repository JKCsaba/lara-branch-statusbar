#!/usr/bin/env python3
"""Fast, read-only iOS 18.4 SpringBoard Aperture disassembly.
Uses method addresses observed in a 22E240 class dump; requires the exact same firmware cache.
No device interaction. No dynamic hooks. Intended for GitHub Actions runner.
"""
import argparse
import json
import pathlib
import subprocess
import sys
import time

TARGETS = [
    ('rotation_transform', '0x1d83b36d0', 'SBSystemApertureViewControllerRotationTransitionContext -transformForRotationToInterfaceOrientation:'),
    ('host_orientation_changed', '0x1d87d5ebc', 'SBSystemApertureViewController -hostOrientationDidChangeTo:withPreviousOrientation:context:'),
    ('element_orientation_update', '0x1d87d61a4', 'SBSystemApertureViewController -_updateElementOrientationTo:withTransitionCoordinator:'),
]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dsc', type=pathlib.Path, required=True)
    parser.add_argument('--out', type=pathlib.Path, required=True)
    parser.add_argument('--disass-limit', type=int, default=3)
    opts = parser.parse_args()
    opts.out.mkdir(parents=True, exist_ok=True)
    if not opts.dsc.is_file():
        parser.error(f'No dyld cache at {opts.dsc}')
    results = []
    targets = TARGETS[:max(1, min(3, opts.disass_limit))]
    for index, (name, address, signature) in enumerate(targets, 1):
        out = opts.out / f'disass_{index:02d}_{name}.txt'
        args = ['ipsw', 'dyld', 'disass', str(opts.dsc), '--vaddr', address, '--quiet', '--count', '120']
        print(f'[{index}/{len(targets)}] Starting {name}: {address}; maximum 180 seconds', flush=True)
        started = time.monotonic()
        with out.open('w', encoding='utf-8') as log:
            log.write('CMD: ' + ' '.join(args) + '\n')
            log.flush()
            try:
                proc = subprocess.run(args, stdout=log, stderr=subprocess.STDOUT, timeout=180, check=False)
                status = f'exit={proc.returncode}'
                success = proc.returncode == 0
            except subprocess.TimeoutExpired:
                status = 'TIMEOUT after 180 seconds'
                success = False
            except Exception as exc:
                status = f'ERROR: {exc}'
                success = False
            log.write('\nRESULT: ' + status + '\n')
        elapsed = round(time.monotonic() - started, 1)
        item = dict(name=name, vaddr=address, signature=signature, status=status,
                    elapsed_seconds=elapsed, file=out.name, success=success)
        results.append(item)
        print(f'[{index}/{len(targets)}] Finished {name}: {status}, {elapsed}s', flush=True)
        (opts.out / 'SUMMARY.txt').write_text('\n'.join(
            f"{r['vaddr']} | {r['name']} | {r['status']} | {r['elapsed_seconds']}s | {r['file']}" for r in results
        ) + '\n', encoding='utf-8')
        (opts.out / 'fast_method_results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    if not any(x['success'] for x in results):
        print('No successful disassembly; see captured logs and SUMMARY.txt', file=sys.stderr, flush=True)
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
