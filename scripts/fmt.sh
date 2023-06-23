#!/bin/bash

set -eou pipefail

for i in $(find . -type f \( -name '*.libsonnet' -o -name '*.jsonnet' \) -not -path "./vendor" ); do
	echo -e "📋 Formatting: $i";
	jsonnetfmt -i $i
done
