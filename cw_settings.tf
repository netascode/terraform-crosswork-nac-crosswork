### SETTINGS ###

locals {
  settings             = try(local.crosswork.administration.settings, {})
  settings_defaults    = local.defaults.crosswork.administration.settings
  smart_licensing_mode = try(local.settings.smart_licensing.mode, local.settings_defaults.smart_licensing.mode, "direct")

  # Device performance retention: the model names and the controller keys. ptp, synce and gnss keep raw data only.
  retention_device_keys = {
    lsp_traffic             = "CEPM_SRPOLICY"
    crc                     = "CEPM_CRC"
    statistics              = "CEPM_INTERFACE"
    ptp                     = "CEPM_PTP"
    synce                   = "CEPM_SYNCE"
    quality_of_service      = "CEPM_QOS"
    optical_sfp             = "OPTPM_OPTICALSFP"
    optics_lane             = "OPTPM_OPTICSLANE"
    otu_controllers_info    = "OPTPM_OTUCONTROLLERSINFO"
    memory_pool_utilization = "DeviceMemoryUtilInfo"
    device_availability     = "DeviceAvailability"
    environment_temperature = "DeviceEnvTemp"
    cpu_utilization         = "DeviceCpuUtilInfo"
    gnss                    = "CEPM_GNSS"
    srv6_traffic_accounting = "CEPM_SRV6LOCATOR"
  }
  retention_raw_only = ["ptp", "synce", "gnss"]

  # Health settings: the model names and the controller keys of the metrics, all tabs.
  health_keys = merge(
    {
      device_inlet_temperature = "ENVTEMP_envTemperatureInletX100"
      device_availability      = "DVAVAILABILITY_deviceAvailability"
      memory_pool_utilization  = "MEMORY_memoryUtilization"
      environment_temperature  = "ENVTEMP_envTemperatureX100"
      cpu_utilization          = "CPU_cpuUtilization"
      operation_status_down    = "CEPMINTERFACE_ifAdminUpOperDown"
      operation_status_up      = "CEPMINTERFACE_ifAdminUpOperUp"
      out_packet_errors        = "CEPMINTERFACE_ifOutErrorsPercent"
      in_packet_errors         = "CEPMINTERFACE_ifInErrorsPercent"
      out_traffic_utilization  = "CEPMINTERFACE_ifOutUtilization"
      crc_errors               = "CEPMCRC_crcPercentage"
      in_traffic_utilization   = "CEPMINTERFACE_ifInUtilization"
      out_packet_drops         = "CEPMINTERFACE_ifOutDiscardsPercent"
      in_packet_drops          = "CEPMINTERFACE_ifInDiscardsPercent"
      satellite_locks_count    = "CEPMGNSS_gnssModuleSatelliteCount"
      temperature              = "OPTICALSFP_temperature"
      q_margin                 = "OTUCONTROLLERSINFO_qmargin"
      post_fec_ber             = "OTUCONTROLLERSINFO_postFecBer"
      clock_class              = "CEPMPTP_ptpClockClass"
      input_quality_level      = "CEPMSYNCE_syncEqualityLevelInput"
      clock_state              = "CEPMPTP_ptpClockState"
      clock_utc_offset         = "CEPMPTP_ptpClockUTCOffset"
      dropped_traffic_cos_all  = "CEPMQOS_dropBitsPercent"
      dropped_packets_cos_all  = "CEPMQOS_dropPktsPercent"
    },
    { for cos in range(8) : "dropped_traffic_cos_${cos}" => "CEPMQOS_dropBitsPercent_CoS${cos}" },
    { for cos in range(8) : "dropped_packets_cos_${cos}" => "CEPMQOS_dropPktsPercent_CoS${cos}" },
  )
  health_levels = ["healthy", "minor", "major", "critical"]
  health_units = {
    bps  = "BITS_PER_SECOND"
    kbps = "KBITS_PER_SECOND"
    mbps = "MBITS_PER_SECOND"
    gbps = "GBITS_PER_SECOND"
  }

  # The names of the translated PTP/SyncE metrics, in the order of their numbers.
  quality_level_numbers = { for index, name in [
    "NULL", "DNU", "DUS", "FAILED", "INV0", "INV1", "INV2", "INV3", "INV4", "INV5", "INV6", "INV7", "INV8", "INV9", "INV10", "INV11", "INV12",
    "INV13", "INV14", "INV15", "NSUPP", "PRC", "PROV", "PRS", "SEC", "SMC", "SSUA", "SSUB", "ST2", "ST3", "ST3E", "ST4", "STU", "TNC", "UNC", "UNK",
  ] : name => index + 1 }
  clock_state_numbers = { for index, name in ["freerun", "holdover", "acquiring", "frequency-locked", "phase-aligned"] : name => index + 1 }

  # Health rows by controller key, each with the way its levels are written.
  health_rows = merge([for tab, rows in try(local.settings.performance_monitoring.health_settings, {}) : {
    for row in rows : local.health_keys[row.name] => merge(row, {
      kind = row.name == "input_quality_level" ? "quality" : (row.name == "clock_state" ? "state" : (row.name == "clock_utc_offset" ? "offset" : "range"))
    })
  }]...)
  # A level of a row is a range (from and to), or for the metrics with values a list of numbers or of the model names.
  health_categories = { for key, row in local.health_rows : key => flatten([
    for level in local.health_levels : [{
      level = upper(level)
      min   = row.kind == "range" ? try(row[level].from, null) : null
      max   = row.kind == "range" ? try(row[level].to, null) : null
      values = row.kind == "range" ? null : tolist(
        row.kind == "quality" ? [for name in try(tolist(row[level]), []) : local.quality_level_numbers[name]] : (
          row.kind == "state" ? [for name in try(tolist(row[level]), []) : local.clock_state_numbers[name]] : [for number in try(tolist(row[level]), []) : number]
        )
      )
    }] if try(row[level], null) != null
  ]) }

  # Metric thresholds: the metrics of the model, the levels below critical, and the unit of the time metrics.
  threshold_metrics = {
    bandwidth_utilization = "Utilization"
    in_packet_errors      = "Errors"
    in_packet_drops       = "Drops"
    delay                 = "Delay"
    jitter                = "Jitter"
    loss                  = "Loss"
  }
  # An ordered list: the levels go to the controller in ascending order (a map would sort the keys by name).
  threshold_levels = [{ key = "good", severity = "HEALTHY" }, { key = "warning", severity = "MINOR" }, { key = "severe_warning", severity = "MAJOR" }]
  threshold_rows = { for row in try(local.settings.topology.metric_thresholds, []) : local.threshold_metrics[row.name] => {
    time   = contains(["delay", "jitter"], row.name)
    factor = contains(["delay", "jitter"], row.name) && try(row.unit, local.settings_defaults.topology.metric_thresholds.unit, "ms") == "ms" ? 1000 : 1
    row    = row
  } }

  # Trap receivers: the model values and the controller enums.
  trap_modes         = { auth-priv = "AuthPriv", auth-no-priv = "AuthNoPriv", no-auth-no-priv = "NoAuthNoPriv" }
  trap_auth_types    = { hmac-md5 = "HMACMD5", hmac-sha = "HMACSHA" }
  trap_privacy_types = { none = "NONE", cbc-des = "DES", cfb-aes-128 = "AES128", cfb-aes-192 = "AES192", cfb-aes-192c = "CiscoAES192", cfb-aes-256 = "AES256", cfb-aes-256c = "CiscoAES256" }
  # GNMI: the flag of each vendor that the model lists.
  gnmi_flags       = { for vendor in try(local.settings.alarms_and_events.gnmi, []) : vendor.name => vendor.enabled }
  trap_receivers   = { for trap in try(local.settings.alarms_and_events.notification_destinations.trap_receivers, []) : try(trap.name, trap.address) => trap }
  syslog_receivers = { for syslog in try(local.settings.alarms_and_events.notification_destinations.syslog_receivers, []) : try(syslog.name, syslog.address) => syslog }
}

resource "crosswork_login_banner" "login_banner" {
  count        = try(local.settings.pre_login_disclaimer, null) != null ? 1 : 0
  instance     = var.instance
  show_message = try(local.settings.pre_login_disclaimer.enabled, local.settings_defaults.pre_login_disclaimer.enabled, null)
  user_ack     = try(local.settings.pre_login_disclaimer.require_acknowledgement, local.settings_defaults.pre_login_disclaimer.require_acknowledgement, null)
  title        = try(local.settings.pre_login_disclaimer.title, local.settings_defaults.pre_login_disclaimer.title, null)
  message      = try(local.settings.pre_login_disclaimer.message, local.settings_defaults.pre_login_disclaimer.message, null)
  icon         = try("BANNER_ICON_${upper(local.settings.pre_login_disclaimer.icon)}", "BANNER_ICON_${upper(local.settings_defaults.pre_login_disclaimer.icon)}", null)
}

resource "crosswork_survey_settings" "survey" {
  count    = try(local.settings.survey, null) != null ? 1 : 0
  instance = var.instance
  enabled  = try(local.settings.survey.enabled, local.settings_defaults.survey.enabled, null)
}

resource "crosswork_file_servers" "file_servers" {
  count               = try(local.settings.file_servers, null) != null ? 1 : 0
  instance            = var.instance
  ftp_enabled         = try(local.settings.file_servers.ftp_enabled, local.settings_defaults.file_servers.ftp_enabled, null)
  sftp_upload_enabled = try(local.settings.file_servers.sftp_upload_enabled, local.settings_defaults.file_servers.sftp_upload_enabled, null)
}

resource "crosswork_smart_licensing_transport" "smart_licensing" {
  count    = try(local.settings.smart_licensing, null) != null ? 1 : 0
  instance = var.instance
  # The model has three choices, the controller two modes: the proxy choice is DIRECT with a proxy. The controller keeps
  # the Cisco URL in direct mode, so only on-prem sends a URL of its own.
  mode       = local.smart_licensing_mode == "on-prem" ? "ON_PREM" : "DIRECT"
  url        = local.smart_licensing_mode == "on-prem" ? try(local.settings.smart_licensing.url, null) : "https://smartreceiver.cisco.com/licservice/license"
  proxy_host = local.smart_licensing_mode == "http-gateway" ? try(local.settings.smart_licensing.proxy.host, null) : null
  proxy_port = local.smart_licensing_mode == "http-gateway" ? try(local.settings.smart_licensing.proxy.port, null) : null
}

resource "crosswork_backup_destination" "backup_destination" {
  count    = try(local.settings.backup_and_restore.destination, null) != null ? 1 : 0
  instance = var.instance
  # The controller has no delete, so a destroy leaves the destination in place. The password is write-only.
  host_name           = local.settings.backup_and_restore.destination.address
  port                = local.settings.backup_and_restore.destination.port
  username            = local.settings.backup_and_restore.destination.username
  password            = try(local.settings.backup_and_restore.destination.password_version, null) == null ? sensitive(local.settings.backup_and_restore.destination.password) : null
  password_wo         = try(local.settings.backup_and_restore.destination.password_version, null) != null ? sensitive(local.settings.backup_and_restore.destination.password) : null
  password_wo_version = try(local.settings.backup_and_restore.destination.password_version, null)
  remote_path         = local.settings.backup_and_restore.destination.remote_path
}

resource "crosswork_data_retention_device_performance" "device_performance" {
  count    = try(local.settings.data_retention.device_performance, null) != null ? 1 : 0
  instance = var.instance
  # The model gives days and weeks, the controller wants hours.
  rows = { for row in local.settings.data_retention.device_performance : local.retention_device_keys[row.name] => {
    raw_hours    = try(row.raw_hours, local.settings_defaults.data_retention.device_performance.raw_hours)
    hourly_hours = contains(local.retention_raw_only, row.name) ? 0 : try(row.hourly_days, local.settings_defaults.data_retention.device_performance.hourly_days) * 24
    daily_hours  = contains(local.retention_raw_only, row.name) ? 0 : try(row.daily_days, local.settings_defaults.data_retention.device_performance.daily_days) * 24
    weekly_hours = contains(local.retention_raw_only, row.name) ? 0 : try(row.weekly_weeks, local.settings_defaults.data_retention.device_performance.weekly_weeks) * 168
  } }
}

resource "crosswork_data_retention_network_performance" "network_performance" {
  count                    = try(local.settings.data_retention.network_performance, null) != null ? 1 : 0
  instance                 = var.instance
  collect_lsp_state_change = try(local.settings.data_retention.network_performance.collect_lsp_state_change, local.settings_defaults.data_retention.network_performance.collect_lsp_state_change, null)
  collect_lsp_path_change  = try(local.settings.data_retention.network_performance.collect_lsp_path_change, local.settings_defaults.data_retention.network_performance.collect_lsp_path_change, null)
  collect_lsp_utilization  = try(local.settings.data_retention.network_performance.collect_lsp_utilization, local.settings_defaults.data_retention.network_performance.collect_lsp_utilization, null)
  collect_lsp_pm           = try(local.settings.data_retention.network_performance.collect_lsp_pm, local.settings_defaults.data_retention.network_performance.collect_lsp_pm, null)
  collect_link_pm          = try(local.settings.data_retention.network_performance.collect_link_pm, local.settings_defaults.data_retention.network_performance.collect_link_pm, null)
  raw_hours                = try(local.settings.data_retention.network_performance.raw_hours, local.settings_defaults.data_retention.network_performance.raw_hours, null)
  hourly_days              = try(local.settings.data_retention.network_performance.hourly_days, local.settings_defaults.data_retention.network_performance.hourly_days, null)
  daily_days               = try(local.settings.data_retention.network_performance.daily_days, local.settings_defaults.data_retention.network_performance.daily_days, null)
  weekly_weeks             = try(local.settings.data_retention.network_performance.weekly_weeks, local.settings_defaults.data_retention.network_performance.weekly_weeks, null)
}

resource "crosswork_health_settings" "health_settings" {
  count    = length(local.health_rows) != 0 ? 1 : 0
  instance = var.instance
  rows = { for key, row in local.health_rows : key => {
    unit       = key == "OTUCONTROLLERSINFO_postFecBer" ? local.health_units[try(row.unit, local.settings_defaults.performance_monitoring.health_settings.optical_zrp.unit)] : null
    categories = local.health_categories[key]
  } }
}

resource "crosswork_metric_thresholds" "metric_thresholds" {
  count    = length(local.threshold_rows) != 0 ? 1 : 0
  instance = var.instance
  thresholds = { for metric, entry in local.threshold_rows : metric => {
    levels = concat(
      [for level in local.threshold_levels : {
        severity    = level.severity
        upper_value = entry.row[level.key] * entry.factor
      } if try(entry.row[level.key], null) != null],
      # The controller keeps the critical level only when it runs to 100 (a percentage) or has no end (-1, time).
      [{ severity = "CRITICAL", upper_value = entry.time ? -1 : 100 }]
    )
  } }
}

resource "crosswork_topology_discovery_settings" "discovery" {
  count    = try(local.settings.topology.discovery, null) != null ? 1 : 0
  instance = var.instance
  lldp     = try(local.settings.topology.discovery.lldp, local.settings_defaults.topology.discovery.lldp, null)
  cdp      = try(local.settings.topology.discovery.cdp, local.settings_defaults.topology.discovery.cdp, null)
  lag      = try(local.settings.topology.discovery.lag, local.settings_defaults.topology.discovery.lag, null)
}

resource "crosswork_te_general_settings" "te_general_settings" {
  count                                    = try(local.settings.traffic_engineering.general_settings, null) != null ? 1 : 0
  instance                                 = var.instance
  policy_unused_threshold                  = try(local.settings.traffic_engineering.general_settings.policy_unused_threshold_kbps, local.settings_defaults.traffic_engineering.general_settings.policy_unused_threshold_kbps, null)
  policy_provisioning_timeout              = try(local.settings.traffic_engineering.general_settings.policy_provisioning_timeout_seconds, local.settings_defaults.traffic_engineering.general_settings.policy_provisioning_timeout_seconds, null)
  bandwidth_on_demand_provisioning_timeout = try(local.settings.traffic_engineering.general_settings.bandwidth_on_demand_provisioning_timeout_seconds, local.settings_defaults.traffic_engineering.general_settings.bandwidth_on_demand_provisioning_timeout_seconds, null)
  igp_path_request_timeout                 = try(local.settings.traffic_engineering.general_settings.igp_path_request_timeout_seconds, local.settings_defaults.traffic_engineering.general_settings.igp_path_request_timeout_seconds, null)
  policy_details_request_timeout           = try(local.settings.traffic_engineering.general_settings.policy_details_request_timeout_seconds, local.settings_defaults.traffic_engineering.general_settings.policy_details_request_timeout_seconds, null)
}

resource "crosswork_te_link_affinity" "te_link_affinity" {
  for_each     = { for affinity in try(local.settings.traffic_engineering.link_affinities, []) : affinity.name => affinity }
  instance     = var.instance
  name         = each.value.name
  bit_position = each.value.bit_position
}

resource "crosswork_te_flex_algo_affinity" "te_flex_algo_affinity" {
  for_each     = { for affinity in try(local.settings.traffic_engineering.flexalgo_affinities, []) : affinity.name => affinity }
  instance     = var.instance
  name         = each.value.name
  bit_position = each.value.bit_position
}

resource "crosswork_alarm_settings" "alarm_settings" {
  # The cleanup options and the processing flags are one call of the controller: a part left out takes its defaults.
  count                                   = try(local.settings.alarms_and_events.cleanup_options, null) != null || try(local.settings.alarms_and_events.general, null) != null ? 1 : 0
  instance                                = var.instance
  security_device_alarms_cleared_days     = try(local.settings.alarms_and_events.cleanup_options.security_device_alarms_cleared_days, local.settings_defaults.alarms_and_events.cleanup_options.security_device_alarms_cleared_days, null)
  non_security_device_alarms_cleared_days = try(local.settings.alarms_and_events.cleanup_options.non_security_device_alarms_cleared_days, local.settings_defaults.alarms_and_events.cleanup_options.non_security_device_alarms_cleared_days, null)
  all_events_days                         = try(local.settings.alarms_and_events.cleanup_options.all_events_days, local.settings_defaults.alarms_and_events.cleanup_options.all_events_days, null)
  device_alarms_days                      = try(local.settings.alarms_and_events.cleanup_options.device_alarms_days, local.settings_defaults.alarms_and_events.cleanup_options.device_alarms_days, null)
  system_alarms_days                      = try(local.settings.alarms_and_events.cleanup_options.system_alarms_days, local.settings_defaults.alarms_and_events.cleanup_options.system_alarms_days, null)
  network_alarms_days                     = try(local.settings.alarms_and_events.cleanup_options.network_alarms_days, local.settings_defaults.alarms_and_events.cleanup_options.network_alarms_days, null)
  audit_logs_days                         = try(local.settings.alarms_and_events.cleanup_options.audit_logs_days, local.settings_defaults.alarms_and_events.cleanup_options.audit_logs_days, null)
  trap_processing                         = try(local.settings.alarms_and_events.general.trap_processing, local.settings_defaults.alarms_and_events.general.trap_processing, null)
  syslog_processing                       = try(local.settings.alarms_and_events.general.syslog_processing, local.settings_defaults.alarms_and_events.general.syslog_processing, null)
}

resource "crosswork_gnmi_settings" "gnmi" {
  count            = try(local.settings.alarms_and_events.gnmi, null) != null ? 1 : 0
  instance         = var.instance
  cisco_systems    = try(local.gnmi_flags["cisco-systems"], null)
  juniper_networks = try(local.gnmi_flags["juniper-networks"], null)
}

resource "crosswork_static_route" "static_route" {
  for_each      = { for route in try(local.settings.static_routes, []) : "${route.address}/${route.prefix_length}" => route }
  instance      = var.instance
  address       = each.value.address
  prefix_length = each.value.prefix_length
}

resource "crosswork_syslog_destination" "syslog" {
  for_each       = local.syslog_receivers
  instance       = var.instance
  name           = each.key
  address        = each.value.address
  port           = try(each.value.port, local.settings_defaults.alarms_and_events.notification_destinations.syslog_receivers.port, null)
  protocol       = upper(try(each.value.protocol, local.settings_defaults.alarms_and_events.notification_destinations.syslog_receivers.protocol, "udp"))
  certificate_id = try(each.value.certificate_id, null)
}

resource "crosswork_trap_destination" "trap" {
  for_each = local.trap_receivers
  instance = var.instance
  name     = each.key
  address  = each.value.address
  # An IP address (v4 or v6) is sent as such, any other address is a host name.
  address_type         = strcontains(each.value.address, ":") || can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$", each.value.address)) ? "IPADDRESS" : "DNS"
  port                 = try(each.value.port, local.settings_defaults.alarms_and_events.notification_destinations.trap_receivers.port, null)
  transport_type       = upper(try(each.value.notification_type, local.settings_defaults.alarms_and_events.notification_destinations.trap_receivers.notification_type, "udp"))
  snmp_version         = try(each.value.snmp_version, local.settings_defaults.alarms_and_events.notification_destinations.trap_receivers.snmp_version, "v2c") == "v3" ? "VERSION_3" : "VERSION_2C"
  community            = try(each.value.community_version, null) == null ? sensitive(try(each.value.community, null)) : null
  community_wo         = try(each.value.community_version, null) != null ? sensitive(try(each.value.community, null)) : null
  community_wo_version = try(each.value.community_version, null)
  username             = try(each.value.username, null)
  mode                 = try(local.trap_modes[each.value.mode], null)
  auth_type            = try(local.trap_auth_types[each.value.auth_type], null)
  # The mode auth-no-priv needs the privacy type NONE, which the model leaves out.
  privacy_type                = try(local.trap_privacy_types[each.value.privacy_type], try(each.value.mode, null) == "auth-no-priv" ? "NONE" : null)
  auth_password               = try(each.value.auth_password_version, null) == null ? sensitive(try(each.value.auth_password, null)) : null
  auth_password_wo            = try(each.value.auth_password_version, null) != null ? sensitive(try(each.value.auth_password, null)) : null
  auth_password_wo_version    = try(each.value.auth_password_version, null)
  privacy_password            = try(each.value.privacy_password_version, null) == null ? sensitive(try(each.value.privacy_password, null)) : null
  privacy_password_wo         = try(each.value.privacy_password_version, null) != null ? sensitive(try(each.value.privacy_password, null)) : null
  privacy_password_wo_version = try(each.value.privacy_password_version, null)
}
