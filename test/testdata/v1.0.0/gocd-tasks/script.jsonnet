local gocdtasks = import '../../../../v1.0.0/gocd-tasks.libsonnet';

{
  tasks: [
    gocdtasks.script("echo 'hello'"),
    gocdtasks.script(importstr '../../sample-bash.sh'),
  ],
}
