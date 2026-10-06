#!/bin/sh
# Stands in for one tool the wiki staleness gate runs, in
# tools/hooks/openwiki_staleness_test.sh: it runs the real tool, $REAL_TOOL,
# with its arguments, prints what that prints, and then fails with status 7
# when $FAIL_WHEN says so — the case where a failure would most easily pass for
# success:
#
#   always          every run;
#   second-run      the second run only, counted in "$0.count";
#   counting-rows   awk counting the rows collected (`END {print NR}` over */rows);
#   counting-lines  awk given anything but the collected rows.
"$REAL_TOOL" "$@"
status=$?
case $FAIL_WHEN in
  always) exit 7 ;;
  second-run)
    n=$(cat "$0.count" 2>/dev/null || echo 0)
    n=$((n + 1))
    echo "$n" >"$0.count"
    [ "$n" -eq 2 ] && exit 7
    ;;
  counting-rows)
    if [ "${1:-}" = "END {print NR}" ]; then
      case "${2:-}" in */rows) exit 7 ;; esac
    fi
    ;;
  counting-lines)
    case "${2:-}" in */rows) ;; *) exit 7 ;; esac
    ;;
  *)
    echo "failing_tool.sh: unknown FAIL_WHEN '$FAIL_WHEN'" >&2
    exit 2
    ;;
esac
exit $status
