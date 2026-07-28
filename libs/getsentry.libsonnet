/***
* sentry-specific helpers
*/

// `edge` is the sentry-edge `primary` cluster. It is an ordinary region cluster
// and gets an ordinary single-region group, exactly like us/de/s4s2/control.
local edge_region = 'edge';

// pop-rr is the canary cluster for the PoP fleet. The PoPs have no in-cluster
// canary deployments the way the SaaS regions do -- one whole cluster plays that
// role instead -- so it deploys as its own group, ahead of the rest, and acts as
// the gate for them.
local edge_pop_canary_regions = ['edge-pop-rr'];

// The PoPs the canary gates. They share a group so they deploy as parallel jobs:
// there is no meaningful order between them, and alphabetical order in
// particular implies a sequencing that does not exist. Adding a PoP here needs
// no ordering decision.
local edge_pop_gated_regions = [
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
  'edge-pop-sc',
  'edge-pop-sg',
  'edge-pop-tx',
  'edge-pop-va',
];

// All 16 edge clusters. The PoPs are modelled as pseudo-regions (like the uptime
// clusters) so each one gets its own diff/apply job. Every entry is
// default-excluded in pipedream.libsonnet, so a service reaches edge only by
// opting in via include_regions -- the same treatment control and snty-tools
// get, and for the same reason: most services render no manifests there.
//
// Kept as file-level locals rather than fields so that pipeline_groups does not
// depend on `self` -- pipeline_groups gets copied into other objects, which
// would rebind `self` and break the reference.
local edge_pop_regions = edge_pop_canary_regions + edge_pop_gated_regions;
local edge_regions = [edge_region] + edge_pop_regions;

{
  edge_regions:: edge_regions,

  // All 15 PoPs, canary included -- deliberately not the same set as the
  // `edge-pop` group, which holds only the 14 the canary gates. A service that
  // runs on the PoPs wants all 15 in its include_regions; pipedream then splits
  // them across the canary and gated groups on its behalf.
  edge_pop_regions:: edge_pop_regions,

  // The edge groups trail the SaaS regions: these are ingest-path clusters, so
  // they should only move after the regions they front are known good. Within
  // edge, the primary cluster goes first, then the canary PoP gates the rest.
  group_order: [
    's4s2',
    'de',
    'us',
    'us2',
    'control',
    'prod-control',
    'snty-tools',
    'edge',
    'edge-pop-canary',
    'edge-pop',
    'st',
  ],
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
    edge: [edge_region],
    'edge-pop-canary': edge_pop_canary_regions,
    'edge-pop': edge_pop_gated_regions,
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
