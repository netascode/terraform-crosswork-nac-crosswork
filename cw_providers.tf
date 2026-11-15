### PROVIDER PROFILES ###

locals {
  providers_profiles = try(local.crosswork.providers.profiles, [])

  provider_profile_families = {
    NSO            = "ROBOT_PROVIDER_NSO"
    WAE            = "ROBOT_PROVIDER_WAE"
    SR_PCE         = "ROBOT_PROVIDER_XTC"
    SYSLOG_STORAGE = "ROBOT_PROVIDER_SYSLOG_STORAGE"
    ALERT          = "ROBOT_PROVIDER_ALERT"
    PROXY          = "ROBOT_PROVIDER_PROXY"
    ONC            = "ROBOT_PROVIDER_ONC"
    ACCEDIAN_PROXY = "ROBOT_PROVIDER_ACCEDIAN_PROXY"
  }

  provider_profile_protocols = {
    SSH     = "ROBOT_MSVC_TRANS_SSH"
    NETCONF = "ROBOT_MSVC_TRANS_NETCONF"
    HTTP    = "ROBOT_MSVC_TRANS_HTTP"
    HTTPS   = "ROBOT_MSVC_TRANS_HTTPS"
    GRPC    = "ROBOT_MSVC_TRANS_GRPC"
    GNMI    = "ROBOT_MSVC_TRANS_GNMI"
  }

  provider_profile_model_prefixes = {
    cisco-ios-xr = "Cisco-IOS-XR"
    cisco-nx-os  = "Cisco-NX-OS"
    cisco-ios-xe = "Cisco-IOS-XE"
  }
}

resource "crosswork_provider_profiles" "provider_profile" {
  for_each = { for provider_profile in local.providers_profiles : provider_profile.name => provider_profile }
  instance = var.instance
  name     = each.value.name
  family   = local.provider_profile_families[each.value.family]
  profile  = try(crosswork_credential_profiles.credential_profile[each.value.credential_profile].id, each.value.credential_profile)
  connectivity = [for connection in each.value.connectivity : {
    protocol         = local.provider_profile_protocols[connection.protocol]
    ip_address       = try(connection.ip_address, local.defaults.crosswork.providers.profiles.connectivity.ip_address, null)
    fqdn_host_name   = try(connection.fqdn.host_name, local.defaults.crosswork.providers.profiles.connectivity.fqdn.host_name, null)
    fqdn_domain_name = try(connection.fqdn.domain_name, local.defaults.crosswork.providers.profiles.connectivity.fqdn.domain_name, null)
    port             = connection.port
    timeout          = try(connection.timeout, local.defaults.crosswork.providers.profiles.connectivity.timeout, null)
    encoding_type    = try(connection.encoding_type, local.defaults.crosswork.providers.profiles.connectivity.encoding_type, null)
  }]
  certificate_name = try(each.value.certificate_profile, local.defaults.crosswork.providers.profiles.certificate_profile, null)
  supported_models = try(length(each.value.models) == 0, true) ? null : [for model in each.value.models : {
    model_prefix  = local.provider_profile_model_prefixes[model.prefix]
    model_version = tostring(model.version)
  }]
  properties = try(each.value.properties, local.defaults.crosswork.providers.profiles.properties, null)
}

### NSO PROVIDER POLICIES ###

resource "crosswork_provider_nso_policies" "nso_policy" {
  for_each              = { for policy in try(local.crosswork.providers.nso_policies, []) : policy.provider_name => policy }
  instance              = var.instance
  provider_name         = each.value.provider_name
  match                 = try(each.value.match, local.defaults.crosswork.providers.nso_policies.match, null)
  match_rule            = try(each.value.match_rule, local.defaults.crosswork.providers.nso_policies.match_rule, null)
  onboard_to_nso        = try(each.value.onboard_to_nso, local.defaults.crosswork.providers.nso_policies.onboard_to_nso, null)
  onboard_to_nso_rule   = try(each.value.onboard_to_nso_rule, local.defaults.crosswork.providers.nso_policies.onboard_to_nso_rule, null)
  onboard_from_nso      = try(each.value.onboard_from_nso, local.defaults.crosswork.providers.nso_policies.onboard_from_nso, null)
  onboard_from_nso_rule = try(each.value.onboard_from_nso_rule, local.defaults.crosswork.providers.nso_policies.onboard_from_nso_rule, null)
  sync_from_nso         = try(each.value.sync_from_nso, local.defaults.crosswork.providers.nso_policies.sync_from_nso, null)
  sync_from_nso_rule    = try(each.value.sync_from_nso_rule, local.defaults.crosswork.providers.nso_policies.sync_from_nso_rule, null)
  check_sync            = try(each.value.check_sync, local.defaults.crosswork.providers.nso_policies.check_sync, null)
  check_sync_rule       = try(each.value.check_sync_rule, local.defaults.crosswork.providers.nso_policies.check_sync_rule, null)
  neds = try(length(each.value.neds) == 0, true) ? null : [for ned in each.value.neds : {
    ned  = ned.ned
    rule = ned.rule
  }]

  depends_on = [crosswork_provider_profiles.provider_profile]
}
