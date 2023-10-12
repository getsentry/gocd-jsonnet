local gocdstages = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-stages.libsonnet';
local gocdtasks = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-tasks.libsonnet';

// A single job stage, with a noop task and allow only on success approval
gocdstages.basic('example-stage', [gocdtasks.noop], { approval: 'success' })
