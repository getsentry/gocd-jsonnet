/***
* sentry-specific helpers
*/

{
  // These regions are user facing deployments
  prod_regions: [
    's4s',
    'us',
    //'de',   // pending https://github.com/getsentry/devinfra-deployment-service/pull/496
    'customer-1',
    'customer-2',
    'customer-3',
    'customer-4',
  ],
  // Test regions will deploy in parallel to the regions above
  test_regions: [
    'customer-5',
    'customer-6',
  ],
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
}
