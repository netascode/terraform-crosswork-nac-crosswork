### CREDENTIAL PROFILES ###

locals {
  credential_types = {
    SSH     = "ROBOT_USERPASS_SSH"
    NETCONF = "ROBOT_USERPASS_NETCONF"
    HTTP    = "ROBOT_USERPASS_HTTP"
    HTTPS   = "ROBOT_USERPASS_HTTPS"
    TELNET  = "ROBOT_USERPASS_TELNET"
    GRPC    = "ROBOT_USERPASS_GRPC"
    GNMI    = "ROBOT_USERPASS_GNMI"
  }

  credential_profiles = { for profile in try(local.crosswork.device_management.credential_profiles, []) : profile.name => {
    userpass = [for credential in try(profile.credentials, []) : credential if contains(keys(local.credential_types), credential.type)]
    snmpv2   = try([for credential in profile.credentials : credential if credential.type == "SNMPv2"][0], null)
    snmpv3   = try([for credential in profile.credentials : credential if credential.type == "SNMPv3"][0], null)
  } }
}

resource "crosswork_credential_profiles" "credential_profile" {
  for_each = local.credential_profiles
  instance = var.instance
  profile  = each.key
  credentials = length(each.value.userpass) == 0 ? null : [for credential in each.value.userpass : {
    type                             = local.credential_types[credential.type]
    user_name                        = credential.user_name
    password                         = try(credential.password_version, null) == null ? sensitive(credential.password) : null
    password_wo                      = try(credential.password_version, null) != null ? sensitive(credential.password) : null
    password_wo_version              = try(credential.password_version, null)
    enable_password                  = try(credential.enable_password, local.defaults.crosswork.device_management.credential_profiles.credentials.enable_password, null) == null ? null : (try(credential.enable_password, local.defaults.crosswork.device_management.credential_profiles.credentials.enable_password) ? "ROBOT_USERPASSEN_ENABLE" : "ROBOT_USERPASSEN_DISABLE")
    enable_password_value            = try(credential.enable_password_value_version, null) == null ? sensitive(try(credential.enable_password_value, null)) : null
    enable_password_value_wo         = try(credential.enable_password_value_version, null) != null ? sensitive(try(credential.enable_password_value, null)) : null
    enable_password_value_wo_version = try(credential.enable_password_value_version, null)
  }]
  snmpv2_read_community             = try(each.value.snmpv2.read_community_version, null) == null ? sensitive(try(each.value.snmpv2.read_community, null)) : null
  snmpv2_read_community_wo          = try(each.value.snmpv2.read_community_version, null) != null ? sensitive(try(each.value.snmpv2.read_community, null)) : null
  snmpv2_read_community_wo_version  = try(each.value.snmpv2.read_community_version, null)
  snmpv2_write_community            = try(each.value.snmpv2.write_community_version, null) == null ? sensitive(try(each.value.snmpv2.write_community, null)) : null
  snmpv2_write_community_wo         = try(each.value.snmpv2.write_community_version, null) != null ? sensitive(try(each.value.snmpv2.write_community, null)) : null
  snmpv2_write_community_wo_version = try(each.value.snmpv2.write_community_version, null)
  snmpv3_user_name                  = try(each.value.snmpv3.user_name, null)
  snmpv3_security_level             = try("SL_${each.value.snmpv3.security_level}", null) # the API names carry a prefix the page does not show
  snmpv3_auth_type                  = try("AT_${each.value.snmpv3.auth_type}", null)
  snmpv3_priv_type                  = try("PT_${each.value.snmpv3.priv_type}", null)
  snmpv3_auth_password              = try(each.value.snmpv3.auth_password_version, null) == null ? sensitive(try(each.value.snmpv3.auth_password, null)) : null
  snmpv3_auth_password_wo           = try(each.value.snmpv3.auth_password_version, null) != null ? sensitive(try(each.value.snmpv3.auth_password, null)) : null
  snmpv3_auth_password_wo_version   = try(each.value.snmpv3.auth_password_version, null)
  snmpv3_priv_password              = try(each.value.snmpv3.priv_password_version, null) == null ? sensitive(try(each.value.snmpv3.priv_password, null)) : null
  snmpv3_priv_password_wo           = try(each.value.snmpv3.priv_password_version, null) != null ? sensitive(try(each.value.snmpv3.priv_password, null)) : null
  snmpv3_priv_password_wo_version   = try(each.value.snmpv3.priv_password_version, null)
}
