#!/bin/bash

# Note: $REGION_PIPELINE_FLAGS has no quoting, for word expansion
# shellcheck disable=SC2086
if [[ "${REGION_PIPELINE_FLAGS:-}" ]]; then
  set -- $REGION_PIPELINE_FLAGS
fi

# Get sha from the given pipeline run to deploy to all pipedream pipelines.
sha=$(gocd-sha-for-pipeline --material-name="${ROLLBACK_MATERIAL_NAME}")

gocd-emergency-deploy \
  --commit-sha="${sha}" \
  --deploy-stage="${ROLLBACK_STAGE}" \
  --pause-message="This pipeline was rolled back, please check with team before un-pausing." \
  "$@"
