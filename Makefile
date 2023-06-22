fmt:
	find . -type f \( -name '*.libsonnet' -o -name '*.jsonnet' \) -exec echo {} \; -exec jsonnetfmt -i {} \;

fmt-ci:
	find . -type f \( -name '*.libsonnet' -o -name '*.jsonnet' \) -exec echo {} \; -exec jsonnetfmt --test {} \;

lint:
	find . -type f \( -name '*.libsonnet' -o -name '*.jsonnet' \) -exec echo {} \; -exec jsonnet-lint {} \;
