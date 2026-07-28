/***
* sentry-specific helpers
*/

// The edge region and its 15 points-of-presence clusters. The PoPs are
// modelled as pseudo-regions (like the uptime clusters) so each one gets its
// own diff/apply job; `edge` itself is the sentry-edge `primary` cluster.
// Every entry here is default-excluded in pipedream.libsonnet, so a service
// only deploys to edge if it opts in via include_regions.
//
// Kept as a file-level local rather than a field so that `pipeline_groups.edge`
// does not depend on `self` — pipeline_groups gets copied into other objects,
// which would rebind `self` and break the reference.
local edge_regions = [
  'edge',
  'edge-pop-au',
  'edge-pop-br',
  'edge-pop-ca',
  'edge-pop-de',
  'edge-pop-fi',
  'edge-pop-in',
  'edge-pop-jp',
  'edge-pop-nl',
  'edge-pop-or',
  'edge-pop-qa',
  'edge-pop-rr',
  'edge-pop-sc',
  'edge-pop-sg',
  'edge-pop-tx',
  'edge-pop-va',
];

{
  edge_regions:: edge_regions,

  // `edge` trails the SaaS regions: these are ingest-path clusters, so they
  // should only move after the regions they front are known good.
  group_order: ['s4s2', 'de', 'us', 'us2', 'control', 'prod-control', 'snty-tools', 'edge', 'st'],
  // Empty for now — add future test groups here
  test_group_order: [],
  // These groupings consist of user facing deployments
  pipeline_groups: {
    s4s2: ['s4s2'],
    de: ['de'],
    us: ['us'],
    us2: ['us2'],
    control: ['control'],
    'prod-control': ['prod-control'],
    'snty-tools': ['snty-tools'],
    edge: edge_regions,
    st: ['customer-1', 'customer-2', 'customer-7'],
  },
  // Test groups will deploy in parallel to the groups above
  test_groups: {
  },

  group_names:: self.group_order,
  test_group_names:: self.test_group_order,
  get_targets(group)::
    if std.objectHas(self.pipeline_groups, group) then self.pipeline_groups[group]
    else self.test_groups[group],
  is_st(region):: std.startsWith(region, 'customer-'),
}
