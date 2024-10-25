/***
* sentry-specific helpers
*/

{
  // These regions are user facing deployments
  prod_regions: [
    's4s',
    'de',
    'us',
    // 'control' is excluded by default and must be explicitly included
    'control',
    'customer-1',
    'customer-2',
    'customer-4',
    'customer-7',
  ],
  // Test regions will deploy in parallel to the regions above
  test_regions: [
  ],
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
  prod_region_pops: {
    de: [
      'de',
      'de-pop-regional-1',
      'de-pop-regional-2',
    ],
    us: [
      'us',
      'us-pop-regional-1',
      'us-pop-regional-2',
      'us-pop-regional-3',
      'us-pop-regional-4',
      'us-pop-1',
      'us-pop-2',
    ],
  },
  test_region_pops: null
}
