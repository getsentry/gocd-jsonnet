local getsentry = import '../../../libs/getsentry.libsonnet';

{
  s4s: getsentry.is_st('s4s'),
  us: getsentry.is_st('us'),
  eu: getsentry.is_st('eu'),
  'customer-1': getsentry.is_st('customer-1'),
  'customer-a': getsentry.is_st('customer-a'),
  'demo-customer': getsentry.is_st('demo-customer'),
}
