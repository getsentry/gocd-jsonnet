local gocd_stages = import '../../../src/gocd-stages.libsonnet';

gocd_stages.basic('example', [], { approval: 'manual' })
