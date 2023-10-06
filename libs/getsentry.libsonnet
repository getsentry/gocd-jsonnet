local REGIONS = [
  's4s',
  'us',
  'customer-1',
  'customer-2',
  'customer-3',
  'customer-4',
];
// Test regions will deploy in parallel to the regions above
local TEST_REGIONS = [
  'customer-5',
  'customer-6',
];

{
  regions: REGIONS,
  test_regions: TEST_REGIONS,
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
}
