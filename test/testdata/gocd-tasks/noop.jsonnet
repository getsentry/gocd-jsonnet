local gocdtasks = import '../../../libs/gocd-tasks.libsonnet';

{
  tasks: [
    gocdtasks.noop,
  ],
}
