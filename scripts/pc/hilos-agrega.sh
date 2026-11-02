#!/bin/bash
LOG=/c/Users/26095/cola/sw-todo/rex/rex_perfil.log
grep -oE '^-- hilo [0-9]+ "[^"]*": CPU [0-9.]+%' "$LOG" \
| sed -E 's/^-- hilo [0-9]+ "([^"]*)": CPU ([0-9.]+)%/\2\t\1/' \
| awk -F'\t' '{sum[$2]+=$1; cnt[$2]++} END {for (n in sum) printf "%9.1f%%  %6d  %s\n", sum[n]/cnt[n], cnt[n], n}' \
| sort -rn | head -30
