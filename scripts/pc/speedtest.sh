#!/usr/bin/env bash
export PATH=/ucrt64/bin:/usr/bin:$PATH
C=c94f5ebdcb3c9d1a460ca48e04f9758448f8d518
for u in "https://gh-proxy.com/https://codeload.github.com/rexglue/rexglue-sdk/tar.gz/$C" "https://codeload.github.com/rexglue/rexglue-sdk/tar.gz/$C"; do
  echo "=== $u"
  rm -f /tmp/t.gz
  curl -sL --max-time 25 -o /tmp/t.gz "$u"
  sz=$(stat -c %s /tmp/t.gz 2>/dev/null || echo 0)
  echo "  25s 拿到 $((sz/1024)) KB  ≈ $((sz/25/1024)) KB/s"
done
