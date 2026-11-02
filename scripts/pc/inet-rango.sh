#!/bin/bash
grep -oE 'imagen\+0x3ec3[0-9a-f]{3}' /c/Users/26095/cola/sw-todo/rex/rex_perfil.log \
| sed 's/imagen+0x//' \
| awk '{ n = strtonum("0x" $0); if (n >= 32735360 && n < 32736136) print }' \
| sort | uniq -c | sort -rn | head -14 \
| while read c off; do printf "%8d  %s\n" "$c" "$off"; done
