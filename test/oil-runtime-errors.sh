#!/usr/bin/env bash
#
# Usage:
#   ./oil-runtime-errors.sh <function name>

# NOTE: No set -o errexit, etc.

source test/common.sh

OIL=${OIL:-bin/oil}

_error-case() {
  $OIL -c "$@"

  # NOTE: This works with osh, not others.
  local status=$?
  if test $status != 1; then
    die "Expected status 1, got $status"
  fi
}

regex_literals() {
  var sq = / 'foo'+ /
  var dq = / "foo"+ /

  var literal = 'foo'
  var svs = / $literal+ /
  var bvs = / ${literal}+ /

  # All of these fail individually.
  # NOTE: They are fatal failures so we can't catch them?  It would be nicer to
  # catch them.

  #echo $sq
  #echo $dq
  #echo $svs
  echo $bvs
}

undefined_vars() {
  set +o errexit

  _error-case 'echo hi; y = 2 + x + 3'
  _error-case 'if (x) { echo hello }'
  _error-case 'if ($x) { echo hi }'
  _error-case 'if (${x}) { echo hi }'

  _error-case 'x = / @yo /'
}

_run-test() {
  local name=$1

  bin/osh -O oil:basic -- $0 $name
  local status=$?
  if test $status -ne 1; then
    die "Expected status 1, got $status"
  fi
}

run-all-with-osh() {
  _run-test regex_literals
  _run-test undefined_vars

  return 0  # success
}

run-for-release() {
  run-other-suite-for-release oil-runtime-errors run-all-with-osh
}

"$@"
