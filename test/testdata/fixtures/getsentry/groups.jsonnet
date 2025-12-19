local getsentry = import '../../../../libs/getsentry.libsonnet';

{
  all_groups: getsentry.pipeline_groups + getsentry.test_groups,
  group_order: getsentry.group_order + getsentry.test_group_order,
}
