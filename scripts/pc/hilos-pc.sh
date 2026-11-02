#!/bin/bash
LOG=/c/Users/26095/cola/sw-todo/rex/rex_perfil.log
sed -n -E \
  -e 's/^-- hilo [0-9]+ "([^"]*)".*/@THREAD@\1/p' \
  -e 's/^ +([0-9.]+)% +pc imagen\+0x([0-9a-f]+).*/\1\t\2/p' \
  "$LOG" \
| awk -F'\t' '
/@THREAD@/ { cur=substr($0,9); next }
NF==2 {
  key=cur SUBSEP $2; sum[key]+=$1; cnt[key]++;
  if (!seen[cur]++) torder[++tn]=cur;
  if (!pseen[key]++) { porder[key]=++pn }
}
END {
  for (t=1; t<=tn; t++) {
    cur=torder[t];
    if (cur !~ /^(XThread825EFC40|XThread825E9560|XThread82616000|GPU anillo nati|Main XThread)/) continue;
    print "== " cur;
    m=0;
    for (k in sum) { split(k,q,SUBSEP); if (q[1]==cur) { m++; val[m]=sum[k]; id[m]=q[2] } }
    # insertion sort desc
    for (i=2;i<=m;i++){v=val[i];d=id[i];for(j=i-1;j>=1&&val[j]<v;j--){val[j+1]=val[j];id[j+1]=id[j]}val[j+1]=v;id[j+1]=d}
    for (i=1;i<=12&&i<=m;i++) printf "   %8.1f%%  imagen+%s\n", val[i], id[i];
  }
}' | awk '!seen[$0]++'
