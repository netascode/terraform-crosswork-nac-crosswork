### NSO PROVIDER POLICIES ###

resource "crosswork_nso_provider_policies" "nso_policy" {
  for_each              = { for policy in try(local.crosswork.administration.nso_policies, []) : policy.provider_name => policy }
  instance              = var.instance
  provider_name         = each.value.provider_name
  match                 = try(each.value.match, local.defaults.crosswork.administration.nso_policies.match, null)
  match_rule            = try(each.value.match_rule, local.defaults.crosswork.administration.nso_policies.match_rule, null)
  onboard_to_nso        = try(each.value.onboard_to_nso, local.defaults.crosswork.administration.nso_policies.onboard_to_nso, null)
  onboard_to_nso_rule   = try(each.value.onboard_to_nso_rule, local.defaults.crosswork.administration.nso_policies.onboard_to_nso_rule, null)
  onboard_from_nso      = try(each.value.onboard_from_nso, local.defaults.crosswork.administration.nso_policies.onboard_from_nso, null)
  onboard_from_nso_rule = try(each.value.onboard_from_nso_rule, local.defaults.crosswork.administration.nso_policies.onboard_from_nso_rule, null)
  sync_from_nso         = try(each.value.sync_from_nso, local.defaults.crosswork.administration.nso_policies.sync_from_nso, null)
  sync_from_nso_rule    = try(each.value.sync_from_nso_rule, local.defaults.crosswork.administration.nso_policies.sync_from_nso_rule, null)
  check_sync            = try(each.value.check_sync, local.defaults.crosswork.administration.nso_policies.check_sync, null)
  check_sync_rule       = try(each.value.check_sync_rule, local.defaults.crosswork.administration.nso_policies.check_sync_rule, null)
  neds = try(length(each.value.neds) == 0, true) ? null : [for ned in each.value.neds : {
    ned  = ned.ned
    rule = ned.rule
  }]

  depends_on = [crosswork_provider_profiles.provider_profile]
}
