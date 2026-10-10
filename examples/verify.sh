#!/usr/bin/env bash
# Verifier for examples/. Run from repo root:  ./examples/verify.sh
# Re-runnable. Uses a fake `paru` in /tmp, never touches the real system.
# Real runs use --no-root-check: the demos only touch the repo and /tmp.
#   1. Proves --dry-run never mutates files (sha256 before/after).
#   2. Applies the batch for real and checks every expected result.
#   3. Runs neg/ cases, expecting failures (and no mutations).
set -u
cd "$(dirname "$0")/.." || exit 1

P="bin/n0ct-patch"; E="examples/patches"; W="examples/work"
# Real runs refuse to work without root; the demos only touch the repo
# and /tmp, so the test hatch is safe here. Dry-runs need no privileges.
NR="--no-root-check"
AP="/tmp/n0ct-verify-applied.txt"
DRY_AP="/tmp/n0ct-verify-dry.txt"
SHIM="/tmp/n0ct-verify-shim"
PARU_LOG="/tmp/n0ct-verify-paru.log"

pass=0; fail=0
ok()      { if [ "$1" = "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $3"; fi; }
have()    { if grep -qF "$2" "$1"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $3 ($1 lacks [$2])"; fi; }
absent()  { if grep -qF "$2" "$1"; then fail=$((fail+1)); echo "FAIL: $3 ($1 still has [$2])"; else pass=$((pass+1)); fi; }
gone()    { if [ ! -e "$1" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $2 still exists: $1"; fi; }
snap()    { sha256sum $W/* 2>/dev/null | sha256sum | cut -d' ' -f1; }

echo "== 1. dry-run must not mutate anything =="
before=$(snap)
for f in "$E"/01-*.yaml "$E"/02-*.yaml "$E"/03-*.yaml "$E"/04-*.yaml "$E"/05-*.yaml "$E"/06-*.yaml; do
  $P "$f" --dry-run > /dev/null || { echo "FAIL: dry-run $f exited $?"; fail=$((fail+1)); }
done
$P --apply-missing --patches-dir "$E" --applied-file "$DRY_AP" --dry-run > /dev/null \
  || { echo "FAIL: batch dry-run exited $?"; fail=$((fail+1)); }
after=$(snap)
ok "$before" "$after" "dry-run mutated work files"
gone "$DRY_AP" "dry-run wrote the applied file"

echo "== 2. real batch apply (paru shimmed) =="
rm -rf "$SHIM" && mkdir -p "$SHIM"
printf '#!/bin/bash\necho "paru $*" >> %s\nexit 0\n' "$PARU_LOG" > "$SHIM/paru"
chmod +x "$SHIM/paru"
rm -f "$PARU_LOG" "$AP"
PATH="$SHIM:$PATH" $P --apply-missing --patches-dir "$E" --applied-file "$AP" $NR > /dev/null
ok "$?" "0" "batch apply failed"

T="$W/theme.conf"; A="$W/app.conf"; S="$W/spacing.conf"; R="$W/ports.conf"; N="$W/no-trailing-nl.conf"
have "$T" "hl.gapsin = 6" "theme line1"
have "$T" "hl.gapsin     =     6" "theme spacing preserved"
have "$T" "hlXgapsin = 99" "literal dot untouched"
have "$T" "  hl.gapsin=6 # override" "theme indent+comment preserved"
have "$A" "hl.gapsin =        6" "app gapsin whitespace preserved"
have "$A" "cache_size = 512" "app cache_size"
[ "$(grep -c REDACTED "$A")" = "2" ] && pass=$((pass+1)) || { echo "FAIL: app REDACTED count"; fail=$((fail+1)); }
absent "$A" "oldkey123" "app old key gone"
have "$A" "[metrics]" "metrics appended"
have "$S" "debug=true" "tight spacing kept"
have "$S" "debug = true" "normal spacing kept"
have "$S" "debug   =   true" "wide spacing kept"
have "$S" "pad->OUT    end" "whitespace slot replaced"
have "$S" "name = filled" "{::} filled"
grep -q '^name =$' "$S" && pass=$((pass+1)) || { echo "FAIL: bare name line touched"; fail=$((fail+1)); }
have "$R" "port = 9090" "port rewritten"
have "$R" "  port=9090 # legacy" "port indent+comment preserved"
have "$R" "listen 0:8443" "composed pattern"
have "$R" "listen ab:80" "two-char line untouched by *"
have "$R" "  listen   7 : 8443 # web" "composed pattern on spaced line"
have "$R" "port-A = 7" "single-char wildcard hit"
have "$R" "port-AB = 2" "two-char line untouched by *"
absent "$R" " 443" "old port gone"
[ -z "$(tail -c 1 "$N")" ] && pass=$((pass+1)) || { echo "FAIL: missing trailing newline not fixed"; fail=$((fail+1)); }
[ "$(grep -cF '[appended]' "$N")" = "1" ] && pass=$((pass+1)) || { echo "FAIL: append block count"; fail=$((fail+1)); }
[ "$(stat -c %a "$W/cache.conf")" = "644" ] && pass=$((pass+1)) || { echo "FAIL: cache.conf mode"; fail=$((fail+1)); }
gone "$W/doomed.conf" "doomed file deleted"
have "$W/markers.log" "note-a" "pre-a ran"
have "$W/markers.log" "note-b" "pre-b ran"
[ -f "$W/app.conf.bak" ] && pass=$((pass+1)) || { echo "FAIL: pre backup missing"; fail=$((fail+1)); }
[ "$(wc -l < "$AP")" = "6" ] && pass=$((pass+1)) || { echo "FAIL: applied file line count"; fail=$((fail+1)); }
[ "$(sed -n '1p' "$PARU_LOG")" = "paru -Rs --noconfirm a c" ] && pass=$((pass+1)) || { echo "FAIL: paru remove line"; fail=$((fail+1)); }
[ "$(sed -n '2p' "$PARU_LOG")" = "paru -Sy --needed --noconfirm b d e" ] && pass=$((pass+1)) || { echo "FAIL: paru install line"; fail=$((fail+1)); }
[ "$(wc -l < "$PARU_LOG")" = "2" ] && pass=$((pass+1)) || { echo "FAIL: paru call count"; fail=$((fail+1)); }

echo "== 2b. re-run is clean (idempotent) =="
PATH="$SHIM:$PATH" $P --apply-missing --patches-dir "$E" --applied-file "$AP" $NR > /dev/null
ok "$?" "0" "batch re-run failed"

echo "== 3. neg/ cases must fail loudly (and change nothing) =="
before=$(snap)
for f in "$E"/neg/*.yaml; do
  $P "$f" $NR > /dev/null 2>&1
  [ "$?" != "0" ] && pass=$((pass+1)) || { echo "FAIL: $f unexpectedly succeeded"; fail=$((fail+1)); }
done
after=$(snap)
ok "$before" "$after" "neg run mutated work files"
$P "$E/neg/neg-no-match.yaml" --dry-run > /dev/null 2>&1
ok "$?" "0" "neg dry-run should exit 0"
$P "$E/neg/neg-cmd-fail.yaml" --dry-run > /dev/null 2>&1
ok "$?" "0" "neg cmd dry-run should exit 0"

echo ""
echo "pass=$pass fail=$fail"
[ "$fail" = "0" ]
