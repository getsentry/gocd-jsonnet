# Releasing

1. Merge your change to `main`.
1. Create a release on [the releases page](https://github.com/getsentry/gocd-jsonnet/releases).

To roll out a release to a service:

1. Update the gocd-jsonnet `version` in the service's `jsonnetfile.json`. The file is usually in `gocd/templates/`, as in [snuba's jsonnetfile.json](https://github.com/getsentry/snuba/blob/f4a99cb98a4784311fc198a14f7bcd8def961f94/gocd/templates/jsonnetfile.json#L11).
1. Run `make gocd` to update the lock file and render the pipelines, as in [snuba's Makefile](https://github.com/getsentry/snuba/blob/f4a99cb98a4784311fc198a14f7bcd8def961f94/Makefile#L97).
1. Review the generated pipelines.
