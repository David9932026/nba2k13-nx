#!/usr/bin/env bash
# Resolve a whitespace separated list of RVAs into sub_XXXXXXXX symbols with gdb.
# Usage: resolve-stack.sh <logfile> [pattern]
set -u
LOG="${1:?log file}"
PAT="${2:-MAINSTACK}"
GDB=/ucrt64/bin/gdb.exe
EXE=/c/Users/26095/cola/coding-cola/project-20261028-112651-101fe126/rex/nba2k13app/out/build/win-amd64-release/nba2k13.exe

mapfile -t LINES < <(grep -a "$PAT" "$LOG")
if [ "${#LINES[@]}" -eq 0 ]; then
  echo "no $PAT lines"
  exit 0
fi

mapfile -t RVAS < <(printf '%s\n' "${LINES[@]}" | sed 's/.*<- //' | tr ' ' '\n' \
  | grep -E '^[0-9A-Fa-f]+$' | tr 'a-f' 'A-F' | sort -u)
echo "unique rvas: ${#RVAS[@]}"

ARGS=()
for r in "${RVAS[@]}"; do
  ARGS+=(-ex "info symbol 0x14${r}")
done
mapfile -t OUT < <("$GDB" -batch "${ARGS[@]}" "$EXE" 2>/dev/null)

declare -A SYM
for i in "${!RVAS[@]}"; do
  line="${OUT[$i]:-}"
  case "$line" in
    *" in section "*) SYM["${RVAS[$i]}"]="${line%% in section *}" ;;
    *) SYM["${RVAS[$i]}"]="?${RVAS[$i]}" ;;
  esac
done

for l in "${LINES[@]}"; do
  ts="${l%%]*}"
  st="${l#*<- }"
  out=""
  for r in $st; do
    R=$(echo "$r" | tr 'a-f' 'A-F')
    out+=" | ${SYM[$R]:-?$r}"
  done
  echo "$ts $out"
done
