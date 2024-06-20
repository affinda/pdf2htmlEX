#!/usr/bin/env bash
set -euo pipefail # Exit on any non-zero exit code, and error on use of undefined var
cd /opt/pdf2html
[[ -v PDF2HTML_PORT ]] || export PDF2HTML_PORT=8000
[[ -v TEST_MODE ]] || export TEST_MODE=0
[[ -v NUM_WORKERS ]] || export NUM_WORKERS=1
[[ -v SENTRY_RELEASE ]] || export SENTRY_RELEASE=""
[[ -v SENTRY_DSN ]] || export SENTRY_DSN=""

echo "VERSION = $SENTRY_RELEASE"

warning_message() {
  echo -e "\033[0;33m  $1  \t\033[0m"
}

if [[ "$TEST_MODE" == "1" ]]; then
  echo "$(coverage --version)"
  exec coverage run -m uvicorn pdf2html_api:app --port $PDF2HTML_PORT --host 0.0.0.0 --workers 1
elif [[ "$NUM_WORKERS" -gt "1" ]]; then
  warning_message "WARNING: Running with more than one worker is not recommended. Please scale horizontally instead."
  warning_message "Running with $NUM_WORKERS workers."
  exec gunicorn -w "$NUM_WORKERS" -k uvicorn.workers.UvicornWorker pdf2html_api:app --bind "0.0.0.0:$PDF2HTML_PORT"
else
  exec uvicorn pdf2html_api:app --port $PDF2HTML_PORT --host 0.0.0.0 --workers 1
fi
