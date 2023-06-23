{
  basic(name, tasks, opts={})::
    local approval = if std.objectHas(opts, 'approval') then
      if opts.approval == 'manual' then
        {
          type: "manual",
        }
      else if opts.approval == 'success' then
        {
          type: 'success',
          allow_only_on_success: true,
        }
    else
      null;

  {
    [name]: {
      [if approval != null then 'approval' else null]: approval,
      jobs: {
        [name]: {
          tasks: tasks,
        }
      }
    }
  }
}
