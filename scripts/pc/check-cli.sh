#!/usr/bin/env bash
OUT=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nfsmw-nx-main/sdk/out/win-amd64
cd "$OUT" || exit 1
run() {
  echo "----- rexglue $* -----"
  out=$(timeout 20 ./rexglue.exe "$@" < /dev/null 2>&1); rc=$?
  echo "rc=$rc"
  printf '%s\n' "$out" | head -25
  echo
}
run --version
run codegen --help
run init --help
