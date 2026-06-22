#!/bin/bash

# Note: $ALLOW_MISSING_FLAGS and $REGION_PIPELINE_FLAGS have no quoting, for word expansion
# shellcheck disable=SC2086
if [[ "${REGION_PIPELINE_FLAGS:-}" || "${ALLOW_MISSING_FLAGS:-}" ]]; then
  set -- $ALLOW_MISSING_FLAGS $REGION_PIPELINE_FLAGS
fi

# The user that triggered the rollback
TRIGGERED_BY="${TRIGGERED_BY:-}"

pause_message='This pipeline was rolled back, please check with team before un-pausing.'

# Include triggered by in the pause message if it is not empty
if [ -n "$TRIGGERED_BY" ]; then
  pause_message="$pause_message Triggered by: $TRIGGERED_BY"
fi

# Get sha from the given pipeline run to deploy to all pipedream pipelines.
sha=$(gocd-sha-for-pipeline --material-name="${ROLLBACK_MATERIAL_NAME}")

echo "📑 Rolling back to sha: ${sha}"

gocd-emergency-deploy \
  --material-name="${ROLLBACK_MATERIAL_NAME}" \
  --commit-sha="${sha}" \
  --deploy-stage="${ROLLBACK_STAGE}" \
  --pause-message="$pause_message" \
  "$@"
