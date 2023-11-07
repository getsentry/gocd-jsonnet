local getsentry = import '../../../../libs/getsentry.libsonnet';

{
  all_regions: getsentry.prod_regions + getsentry.test_regions,
}
