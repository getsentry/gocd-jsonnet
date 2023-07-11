#!/bin/bash

# shellcheck disable=SC2086
if [[ "${PIPELINE_FLAGS:-}" ]]; then
  set -- $PIPELINE_FLAGS   # note: no quoting, for word expansion
fi


# Pause all pipelines in the pipedream
gocd-pause-and-cancel-pipelines \
  --pause-message="This pipeline is being rolled back, please check with team before un-pausing." \
  "$@"

# Get sha from the given pipeline run to deploy to all pipedream pipelines.
sha=$(gocd-sha-for-pipeline --material-name="${ROLLBACK_MATERIAL_NAME}")

gocd-emergency-deploy \
  --commit-sha="${sha}" \
  --deploy-stage="${ROLLBACK_STAGE}" \
  --pause-message="This pipeline was rolled back, please check with team before un-pausing." \
  "$@"
