local final_stage_name(pipeline) =
  local final_stage = pipeline.pipeline.stages[std.length(pipeline.pipeline.stages) - 1];
  std.objectFields(final_stage)[0];

local chain_materials(current_pipeline, previous_pipeline) =
  local final_stage = final_stage_name(previous_pipeline);
  current_pipeline {
    pipeline+: {
      materials+: {
        [previous_pipeline.name + '-' + final_stage]: {
          pipeline: previous_pipeline.name,
          stage: final_stage,
        },
      },
    },
  };

local chain_pipelines(pipelines) =
  [pipelines[0]] + [
    chain_materials(pipelines[i], pipelines[i - 1])
    for i in std.range(1, std.length(pipelines) - 1)
  ];

// This method takes an array of pipelines and produces an object that contains
// the pipelines in format:
// { <pipeline name>.yaml: { ...GoCD metadata + <pipeline name>: <pipeline definition> }.
// This is used to output each pipeline to a seperate file.
local pipelines_to_files_object(pipelines) =
  {
    [pipelines[i].name + '.yaml']: {
      format_version: 10,
      pipelines: {
        [pipelines[i].name]: pipelines[i].pipeline,
      },
    }
    for i in std.range(0, std.length(pipelines) - 1)
  };

// This method takes an array of pipelines and produces an object that contains
// the pipelines in format { <pipeline name>: <pipeline definition> }.
// This is used to output all pipelines in a single file.
local pipelines_to_object(pipelines) =
  {
    [pipelines[i].name]: pipelines[i].pipeline
    for i in std.range(0, std.length(pipelines) - 1)
  };

{
  chain_pipelines(pipelines):: chain_pipelines(pipelines),
  pipelines_to_files_object(pipelines):: pipelines_to_files_object(pipelines),
  pipelines_to_object(pipelines):: pipelines_to_object(pipelines),
  final_stage_name(pipeline):: final_stage_name(pipeline),
}
