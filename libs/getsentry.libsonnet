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
    // 'snty-tools' is excluded by default and must be explicitly included
    'snty-tools',
    'customer-1',
    'customer-2',
    'customer-4',
    'customer-7',
  ],
  // Test regions will deploy in parallel to the regions above
  test_regions: [
  ],
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
}
