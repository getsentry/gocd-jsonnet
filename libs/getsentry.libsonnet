/***
* sentry-specific helpers
*/

{
  // These regions are user facing deployments
  prod_regions: [
    's4s',
    'us',
    'customer-1',
    'customer-2',
    'customer-3',
    'customer-4',
  ],
  // Test regions will deploy in parallel to the regions above
  test_regions: [
    'customer-6',
    'de',
  ],
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
}
