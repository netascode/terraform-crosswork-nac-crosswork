### AAA ###

locals {
  aaa_fallbacks = {
    "never"                                 = "NO_FALLBACK"
    "no-response"                           = "FB_ON_NO_RESPONSE"
    "no-response-or-authentication-failure" = "FB_ON_NORESP_AUTH_FAILURE"
  }
  aaa_idle_timeouts = {
    "10m" = 10
    "15m" = 15
    "30m" = 30
    "1h"  = 60
    "2h"  = 120
    "8h"  = 480
  }
}

resource "crosswork_aaa_tacacs_servers" "tacacs" {
  count    = try(local.crosswork.aaa.tacacs_servers, null) != null ? 1 : 0
  instance = var.instance
  servers = [for server in local.crosswork.aaa.tacacs_servers : {
    host               = server.host
    priority           = server.order
    port               = try(server.port, local.defaults.crosswork.aaa.tacacs_servers.port, null)
    secret             = try(server.secret_version, null) == null ? sensitive(server.secret) : null
    secret_wo          = try(server.secret_version, null) != null ? sensitive(server.secret) : null
    secret_wo_version  = try(server.secret_version, null)
    secret_format      = try(server.secret_format, local.defaults.crosswork.aaa.tacacs_servers.secret_format, null)
    service            = server.service
    retries            = try(server.retries, local.defaults.crosswork.aaa.tacacs_servers.retries, null)
    auth_type          = try(server.auth_type, local.defaults.crosswork.aaa.tacacs_servers.auth_type, null)
    retransmit_timeout = try(server.retransmit_timeout, null)
    interface          = try(server.interface, null)
    policy_id          = try(server.policy_id, null)
    virtual_domain     = try(server.device_access_group_attribute, local.defaults.crosswork.aaa.tacacs_servers.device_access_group_attribute, null)
  }]
}

resource "crosswork_aaa_radius_servers" "radius" {
  count    = try(local.crosswork.aaa.radius_servers, null) != null ? 1 : 0
  instance = var.instance
  servers = [for server in local.crosswork.aaa.radius_servers : {
    host               = server.host
    priority           = server.order
    port               = try(server.port, local.defaults.crosswork.aaa.radius_servers.port, null)
    secret             = try(server.secret_version, null) == null ? sensitive(server.secret) : null
    secret_wo          = try(server.secret_version, null) != null ? sensitive(server.secret) : null
    secret_wo_version  = try(server.secret_version, null)
    secret_format      = try(server.secret_format, local.defaults.crosswork.aaa.radius_servers.secret_format, null)
    retries            = try(server.retries, local.defaults.crosswork.aaa.radius_servers.retries, null)
    auth_type          = try(server.auth_type, local.defaults.crosswork.aaa.radius_servers.auth_type, null)
    retransmit_timeout = try(server.retransmit_timeout, null)
    policy_id          = try(server.policy_id, null)
    virtual_domain     = try(server.device_access_group_attribute, local.defaults.crosswork.aaa.radius_servers.device_access_group_attribute, null)
  }]
}

# One LDAP server of the model is two entries of the API: the login (servers) and the lookup of the role (attribute_servers).
resource "crosswork_aaa_ldap_servers" "ldap" {
  count    = try(local.crosswork.aaa.ldap_servers, null) != null ? 1 : 0
  instance = var.instance
  servers = [for server in local.crosswork.aaa.ldap_servers : {
    name                       = server.name
    order                      = server.order
    ldap_url                   = "ldap://${server.host}:${server.port}"
    bind_dn                    = server.bind_dn
    bind_credential            = try(server.bind_credential_version, null) == null ? sensitive(server.bind_credential) : null
    bind_credential_wo         = try(server.bind_credential_version, null) != null ? sensitive(server.bind_credential) : null
    bind_credential_wo_version = try(server.bind_credential_version, null)
    base_dn                    = server.base_dn
    user_filter                = try(server.user_filter, local.defaults.crosswork.aaa.ldap_servers.user_filter, null)
    dn_format                  = server.dn_format
    principal_attribute_id     = server.principal_attribute_id
    policy_id                  = try(server.device_access_group_attribute, local.defaults.crosswork.aaa.ldap_servers.device_access_group_attribute, null)
    connect_timeout            = try(server.connect_timeout, local.defaults.crosswork.aaa.ldap_servers.connect_timeout, null)
  }]
  attribute_servers = [for server in local.crosswork.aaa.ldap_servers : {
    ldap_url                   = "ldap://${server.host}:${server.port}"
    base_dn                    = server.policy_base_dn
    bind_dn                    = server.bind_dn
    bind_credential            = try(server.bind_credential_version, null) == null ? sensitive(server.bind_credential) : null
    bind_credential_wo         = try(server.bind_credential_version, null) != null ? sensitive(server.bind_credential) : null
    bind_credential_wo_version = try(server.bind_credential_version, null)
    user_filter                = server.policy_map_attribute
    connect_timeout            = try(server.connect_timeout, local.defaults.crosswork.aaa.ldap_servers.connect_timeout, null)
    fail_fast                  = false
    attributes                 = { (server.policy_id) = "policy_id" }
  }]
}

# The metadata files are read from the folder Terraform runs in, so the check is here and not in a rule.
resource "terraform_data" "aaa_validation" {
  count = try(local.crosswork.aaa.sso_services, null) != null ? 1 : 0

  lifecycle {
    precondition {
      condition     = alltrue([for service in local.crosswork.aaa.sso_services : fileexists(service.metadata_file)])
      error_message = "SSO metadata file not found for: ${join(", ", [for service in local.crosswork.aaa.sso_services : "${service.name} (${service.metadata_file})" if !fileexists(service.metadata_file)])}"
    }
  }
}

resource "crosswork_aaa_sso_services" "sso" {
  count    = try(local.crosswork.aaa.sso_services, null) != null ? 1 : 0
  instance = var.instance
  services = [for service in local.crosswork.aaa.sso_services : {
    name              = service.name
    evaluation_order  = service.evaluation_order
    metadata          = base64encode(file(service.metadata_file))
    metadata_location = basename(service.metadata_file)
  }]

  depends_on = [terraform_data.aaa_validation]
}

### AAA SETTINGS ###

resource "crosswork_aaa_session_settings" "session" {
  count                      = try(local.crosswork.aaa.session_settings, null) != null ? 1 : 0
  instance                   = var.instance
  fallback_type              = try(local.aaa_fallbacks[try(local.crosswork.aaa.session_settings.fallback, local.defaults.crosswork.aaa.session_settings.fallback)], null)
  idle_session_timeout       = try(local.aaa_idle_timeouts[try(local.crosswork.aaa.session_settings.idle_timeout, local.defaults.crosswork.aaa.session_settings.idle_timeout)], null)
  parallel_sessions          = try(local.crosswork.aaa.session_settings.parallel_sessions, local.defaults.crosswork.aaa.session_settings.parallel_sessions, null)
  parallel_sessions_per_user = try(local.crosswork.aaa.session_settings.parallel_sessions_per_user, local.defaults.crosswork.aaa.session_settings.parallel_sessions_per_user, null)
  source_ip_auditing         = try(local.crosswork.aaa.session_settings.source_ip_auditing, local.defaults.crosswork.aaa.session_settings.source_ip_auditing, null)
}

resource "crosswork_aaa_password_policy" "password" {
  count                                = try(local.crosswork.aaa.password_policies, null) != null ? 1 : 0
  instance                             = var.instance
  min_password_length                  = try(local.crosswork.aaa.password_policies.min_length, local.defaults.crosswork.aaa.password_policies.min_length, null)
  no_username                          = try(local.crosswork.aaa.password_policies.no_username, local.defaults.crosswork.aaa.password_policies.no_username, null)
  no_cisco_variant                     = try(local.crosswork.aaa.password_policies.no_cisco_variant, local.defaults.crosswork.aaa.password_policies.no_cisco_variant, null)
  no_char_repetition                   = try(local.crosswork.aaa.password_policies.no_char_repetition, local.defaults.crosswork.aaa.password_policies.no_char_repetition, null)
  change_password_on_first_login       = try(local.crosswork.aaa.password_policies.change_on_first_login, local.defaults.crosswork.aaa.password_policies.change_on_first_login, null)
  num_changed_chars_enabled            = try(local.crosswork.aaa.password_policies.min_changed_characters, null) != null
  num_changed_chars                    = try(local.crosswork.aaa.password_policies.min_changed_characters, local.defaults.crosswork.aaa.password_policies.min_changed_characters, null)
  num_reuse_limit_enabled              = try(local.crosswork.aaa.password_policies.password_reuse_limit, null) != null
  num_reuse_limit                      = try(local.crosswork.aaa.password_policies.password_reuse_limit, local.defaults.crosswork.aaa.password_policies.password_reuse_limit, null)
  password_reuse_days_enabled          = try(local.crosswork.aaa.password_policies.password_reuse_days, null) != null
  password_reuse_days                  = try(local.crosswork.aaa.password_policies.password_reuse_days, local.defaults.crosswork.aaa.password_policies.password_reuse_days, null)
  failed_logins_before_lockout_enabled = try(local.crosswork.aaa.password_policies.lockout_attempts, null) != null
  failed_logins_before_lockout         = try(local.crosswork.aaa.password_policies.lockout_attempts, local.defaults.crosswork.aaa.password_policies.lockout_attempts, null)
  lock_out_user_time_enabled           = try(local.crosswork.aaa.password_policies.lockout_minutes, null) != null
  lock_out_user_time                   = try(local.crosswork.aaa.password_policies.lockout_minutes, local.defaults.crosswork.aaa.password_policies.lockout_minutes, null)
  password_expiry_days_enabled         = try(local.crosswork.aaa.password_policies.expiry_days, null) != null
  password_expiry_days                 = try(local.crosswork.aaa.password_policies.expiry_days, local.defaults.crosswork.aaa.password_policies.expiry_days, null)
  days_for_warning_enabled             = try(local.crosswork.aaa.password_policies.expiry_warning_days, null) != null
  days_for_warning                     = try(local.crosswork.aaa.password_policies.expiry_warning_days, local.defaults.crosswork.aaa.password_policies.expiry_warning_days, null)
}
