#!/usr/bin/env bash
# Rocoto entry point for CATChem PREPCHEM (new workflow layout).
set -x

source "${HOMEglobal}/dev/ush/load_modules.sh" run
status=$?
(( status != 0 )) && exit "${status}"

export job="prepchem"
export jobid="${job}.$$"

# Match the old PREPCHEM configuration dependencies.
configs="base fcst prepchem"
for config in ${configs}; do
    source "${EXPDIR}/config.${config}"
    status=$?
    (( status != 0 )) && exit "${status}"
done

"${HOMEglobal}/dev/jobs/JGLOBAL_PREPCHEM"
status=$?
exit "${status}"

