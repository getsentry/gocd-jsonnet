local gocdtasks = import '../../../src/gocd-tasks.libsonnet';

{
  tasks: [
    gocdtasks.script("echo 'hello'"),
    gocdtasks.script(importstr '../sample-bash.sh'),
  ],
}
