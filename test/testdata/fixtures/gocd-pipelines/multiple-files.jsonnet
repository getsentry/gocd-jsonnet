local gocd_pipelines = import '../../../../libs/gocd-pipelines.libsonnet';

gocd_pipelines.pipelines_to_files_object([
  {
    name: 'example-1',
    pipeline: {
      group: 'example-1',
      materials: [],
    },
  },
  {
    name: 'example-2',
    pipeline: {
      group: 'example-2',
      materials: [],
    },
  },
])
