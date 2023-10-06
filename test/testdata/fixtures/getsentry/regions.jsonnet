local getsentry = import '../../../../libs/getsentry.libsonnet';

{
  all_regions: getsentry.regions + getsentry.test_regions,
}
