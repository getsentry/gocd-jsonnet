local gocdtasks = import '../../../src/gocd-tasks.libsonnet';

{
  tasks: [
    gocdtasks.noop,
  ],
}
