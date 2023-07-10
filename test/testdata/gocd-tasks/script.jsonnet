local gocdtasks = import '../../../libs/gocd-tasks.libsonnet';

{
  tasks: [
    gocdtasks.script("echo 'hello'"),
    gocdtasks.script(importstr '../sample-bash.sh'),
  ],
}
