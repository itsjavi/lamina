#!/bin/bash
# CI only: swift test with a watchdog. On GitHub's macOS runners a test run sometimes wedges as it starts: every test
# reports "started" and none ever finishes, until the job times out (an hour for a release). Locally it doesn't
# happen. When the output stops for STALL seconds, this prints a stack sample of the test process (to find the
# cause), kills it and tries again, up to ATTEMPTS times; the build is cached, so a retry costs only the tests.
# Arguments go to swift test.
#   LAMINA_UI_TESTS=1 ./scripts/ci-test.sh --disable-keychain
set -uo pipefail

attempts="${CI_TEST_ATTEMPTS:-3}"
stall="${CI_TEST_STALL_SECONDS:-240}"
log="$(mktemp -t lamina-tests)"

for attempt in $(seq 1 "$attempts"); do
  : > "$log"
  swift test "$@" > "$log" 2>&1 &
  tests=$!
  tail -n +1 -f "$log" &
  echo_log=$!
  last_size=0
  idle=0
  stalled=false
  while kill -0 "$tests" 2>/dev/null; do
    sleep 10
    size=$(wc -c < "$log")
    if [ "$size" -ne "$last_size" ]; then last_size=$size; idle=0; else idle=$((idle + 10)); fi
    if [ "$idle" -ge "$stall" ]; then stalled=true; break; fi
  done
  if $stalled; then
    echo "::warning::Attempt $attempt of $attempts: no test output for ${stall}s, so the run is stuck."
    helper=$(pgrep -n -f swiftpm-testing-helper || true)
    if [ -n "$helper" ]; then
      echo "::group::Stack sample of the stuck test process ($helper)"
      sample "$helper" 3 -file "$log.sample" > /dev/null 2>&1 && cat "$log.sample"
      echo "::endgroup::"
    fi
    pkill -9 -f swiftpm-testing-helper 2> /dev/null
    kill -9 "$tests" 2> /dev/null
    wait "$tests" 2> /dev/null
    kill "$echo_log" 2> /dev/null
    continue
  fi
  wait "$tests"
  status=$?
  sleep 1
  kill "$echo_log" 2> /dev/null
  exit "$status"
done

echo "::error::The tests got stuck on every one of $attempts attempts."
exit 1
