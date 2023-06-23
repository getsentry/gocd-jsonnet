local gocdtasks = import '../../../../v1.0.0/gocd-tasks.libsonnet';

{
  tasks: [
    gocdtasks.noop,
  ],
}
