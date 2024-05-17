/***
* sentry-specific helpers
*/

{
  // These regions are user facing deployments
  prod_regions: [
    's4s',
    'de',
    'us',
    'customer-1',
    'customer-2',
    'customer-3',
    'customer-4',
  ],
  // Test regions will deploy in parallel to the regions above
  test_regions: [
    'customer-7',
  ],
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
}
