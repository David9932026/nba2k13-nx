#!/bin/bash
# Manually run codegen for nba2k13 (the build's codegen step is a no-op "run manually" stamp),
# then re-apply the hand patches to the generated sources.
set -u
export PATH=/ucrt64/bin:/usr/bin:$PATH
PROJ="/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126"
REXGLUE="$PROJ/rex/nfsmw-nx-main/sdk/out/win-amd64/rexglue.exe"
MANIFEST="$PROJ/rex/nba2k13app/nba2k13_manifest.toml"
cd "$PROJ/rex/nba2k13app" || exit 1
echo "=== codegen $(date +%H:%M:%S) ==="
"$REXGLUE" codegen "$MANIFEST" --ignore-stamp > /tmp/cg.log 2>&1
rc=$?
echo "codegen rc=$rc  $(date +%H:%M:%S)"
tail -6 /tmp/cg.log
grep -icE 'error|fatal' /tmp/cg.log | sed 's/^/log error lines: /'
exit $rc
