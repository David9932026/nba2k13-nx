#!/usr/bin/env bash
echo "时间 $(date +%H:%M:%S)"
echo "--- configure 尾部 ---"
tail -3 /tmp/appcfg.log 2>/dev/null
echo "--- build 状态 ---"
if [ -f /tmp/appbuild.log ]; then
  echo "行数: $(wc -l < /tmp/appbuild.log)"
  echo "错误数: $(grep -cE 'error:' /tmp/appbuild.log)"
  echo "进度: $(grep -oE '^\[[0-9]+/[0-9]+\]' /tmp/appbuild.log | tail -1)"
  tail -2 /tmp/appbuild.log
else
  echo "尚未开始编译"
fi
