/***
* sentry-specific helpers
*/

{
  group_order: ['de', 'us', 'control', 'snty-tools', 'st'],
  test_group_order: [],
  // These groupings consist of user facing deployments
  pipeline_groups: {
    de: ['de'],
    us: ['us'],
    control: ['control'],
    'snty-tools': ['snty-tools'],
    st: ['customer-1', 'customer-2', 'customer-4', 'customer-7'],
  },
  // Test groups will deploy in parallel to the groups above
  test_groups: {
  },

  group_names:: self.group_order,
  test_group_names:: self.test_group_order,
  get_targets(group)::
    if std.objectHas(self.pipeline_groups, group) then self.pipeline_groups[group]
    else self.test_groups[group],
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
}
