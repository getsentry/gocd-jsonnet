#!/bin/bash

# Note: $ALL_PIPELINE_FLAGS has no quoting, for word expansion
# shellcheck disable=SC2086
if [[ "${ALL_PIPELINE_FLAGS:-}" ]]; then
  set -- $ALL_PIPELINE_FLAGS
fi

# Pause all pipelines in the pipedream
gocd-pause-and-cancel-pipelines \
  --pause-message="This pipeline is being rolled back, please check with team before un-pausing." \
  "$@"
