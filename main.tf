locals {
  crosswork = try(local.model.crosswork, {})

  # The model for the `model` output, without the write-only secrets (a secret that has a `_version` next to it).
  secret_versions = {
    password              = "password_version"
    enable_password_value = "enable_password_value_version"
    read_community        = "read_community_version"
    write_community       = "write_community_version"
    auth_password         = "auth_password_version"
    priv_password         = "priv_password_version"
    secret                = "secret_version"
    bind_credential       = "bind_credential_version"
  }
  exported_users = [for user in try(local.crosswork.administration.users, []) : {
    for key, value in user : key => value if !(contains(keys(local.secret_versions), key) && try(user[local.secret_versions[key]], null) != null)
  }]
  exported_credential_profiles = [for profile in try(local.crosswork.device_management.credential_profiles, []) : merge(profile,
    try(profile.credentials, null) == null ? {} : {
      credentials = [for credential in profile.credentials : {
        for key, value in credential : key => value if !(contains(keys(local.secret_versions), key) && try(credential[local.secret_versions[key]], null) != null)
      }]
    }
  )]
  exported_golden_variable = { for name, variable in try(local.golden_global_variables, {}) : name => {
    for key, value in variable : key => value if !(key == "value" && try(variable.value_version, null) != null)
  } }
  exported_golden_configuration = merge(try(local.crosswork.golden_configuration, {}),
    try(local.crosswork.golden_configuration.global_variables, null) == null ? {} : {
      global_variables = [for variable in local.crosswork.golden_configuration.global_variables : local.exported_golden_variable[variable.name]]
    },
    try(local.crosswork.golden_configuration.templates, null) == null ? {} : {
      templates = [for template in local.crosswork.golden_configuration.templates : merge(template,
        try(template.variables, null) == null ? {} : {
          variables = [for variable in template.variables : {
            for key, value in variable : key => value if !(key == "value" && try(variable.value_version, null) != null)
          }]
        }
      )]
    },
  )
  exported_network_devices = [for device in try(local.crosswork.device_management.network_devices, []) : merge(device,
    try(device.golden_configuration, null) == null ? {} : {
      golden_configuration = merge(device.golden_configuration, {
        templates = [for applied in device.golden_configuration.templates : merge(applied,
          try(applied.variables, null) == null ? {} : {
            variables = [for variable in applied.variables : {
              for key, value in variable : key => value if !(key == "value" && try(variable.value_version, null) != null)
            }]
          }
        )]
      })
    }
  )]
  exported_aaa_servers = { for kind in ["tacacs_servers", "radius_servers", "ldap_servers"] : kind => [for server in local.crosswork.aaa[kind] : {
    for key, value in server : key => value if !(contains(keys(local.secret_versions), key) && try(server[local.secret_versions[key]], null) != null)
  }] if try(local.crosswork.aaa[kind], null) != null }
  exported_device_management = merge(try(local.crosswork.device_management, {}),
    try(local.crosswork.device_management.credential_profiles, null) == null ? {} : { credential_profiles = local.exported_credential_profiles },
    try(local.crosswork.device_management.network_devices, null) == null ? {} : { network_devices = local.exported_network_devices },
  )
  exported_model = merge(local.model,
    try(local.model.crosswork, null) == null ? {} : {
      crosswork = merge(local.crosswork,
        try(local.crosswork.administration.users, null) == null ? {} : {
          administration = merge(local.crosswork.administration, { users = local.exported_users })
        },
        try(local.crosswork.aaa, null) == null ? {} : {
          aaa = merge(local.crosswork.aaa, local.exported_aaa_servers)
        },
        try(local.crosswork.device_management, null) == null ? {} : {
          device_management = local.exported_device_management
        },
        try(local.crosswork.golden_configuration, null) == null ? {} : {
          golden_configuration = local.exported_golden_configuration
        },
      )
    }
  )
}
