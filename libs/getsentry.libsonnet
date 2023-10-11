/**

This library is a set of sentry specific helpers.

*/

{
  is_st(region):: (region == 's4s' || std.startsWith(region, 'customer-')),
}
