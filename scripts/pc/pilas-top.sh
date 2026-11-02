#!/bin/bash
# Extract "pila" lines with their thread context from rex_perfil.log
awk '
/^-- hilo/ { match($0, /"[^"]*"/); cur=substr($0, RSTART+1, RLENGTH-2); next }
/ pila / {
  sub(/^ +[0-9.]+%  pila /, "");
  print cur "\t" $0;
}' /c/Users/26095/cola/sw-todo/rex/rex_perfil.log > /tmp/pilas.txt
wc -l /tmp/pilas.txt
# Top stacks per thread of interest
for T in 'XThread825EFC40' 'XThread825E9560' 'XThread82616000' 'Main XThread' 'GPU anillo nati'; do
  echo "===== $T"
  grep "^$T	" /tmp/pilas.txt | cut -f2 | sort | uniq -c | sort -rn | head -6
done
