local gocdtasks = import 'github.com/getsentry/gocd-jsonnet/libs/gocd-tasks.libsonnet';

local tasks = [
  // A noop task
  gocdtasks.noop,

  // A script task (i.e. { script: "echo ...." })
  gocdtasks.script("echo 'hello world'"),
  // Import a file, escape comments and output a script task
  gocdtasks.script(importstr './bash/ohai.sh'),
];

tasks
