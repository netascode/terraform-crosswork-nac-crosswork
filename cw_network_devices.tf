### NETWORK DEVICES ###

locals {
  network_devices = try(local.crosswork.device_management.network_devices, [])

  network_device_admin_states = {
    Up        = "ROBOT_ADMIN_STATE_UP"
    Down      = "ROBOT_ADMIN_STATE_DOWN"
    Unmanaged = "ROBOT_ADMIN_STATE_UNMANAGED"
  }

  network_device_reachability_checks = {
    Enable  = "REACH_CHECK_ENABLE"
    Disable = "REACH_CHECK_DISABLE"
  }

  network_device_types = {
    Router  = "NODE_TYPE_ROUTER"
    Switch  = "NODE_TYPE_SWITCH"
    Unknown = "NODE_TYPE_UNKNOWN"
  }

  network_device_syslog_formats = {
    RFC_5424 = "RFC_5424"
    RFC_3164 = "RFC_3164"
    Unknown  = "RFC_UNKNOWN"
  }

  network_device_protocols = {
    SSH     = "ROBOT_MSVC_TRANS_SSH"
    SNMP    = "ROBOT_MSVC_TRANS_SNMP"
    NETCONF = "ROBOT_MSVC_TRANS_NETCONF"
    HTTP    = "ROBOT_MSVC_TRANS_HTTP"
    HTTPS   = "ROBOT_MSVC_TRANS_HTTPS"
    TELNET  = "ROBOT_MSVC_TRANS_TELNET"
    GNMI    = "ROBOT_MSVC_TRANS_GNMI"
    GRPC    = "ROBOT_MSVC_TRANS_GRPC"
  }

  network_device_default_ports = {
    SSH     = 22
    SNMP    = 161
    NETCONF = 830
    HTTP    = 80
    HTTPS   = 443
    TELNET  = 23
  }
}

resource "crosswork_network_devices" "network_device" {
  for_each           = { for device in local.network_devices : device.name => device }
  instance           = var.instance
  name               = each.value.name
  host_name          = try(each.value.host_name, local.defaults.crosswork.device_management.network_devices.host_name, null)
  credential_profile = try(crosswork_credential_profiles.credential_profile[each.value.connectivity.credential_profile].id, each.value.connectivity.credential_profile)
  # A device that names a data gateway is attached to it, which brings it admin up; any other device is down unless
  # the model says otherwise.
  admin_state        = try(local.network_device_admin_states[try(each.value.admin_state, try(each.value.data_gateway, null) != null ? "Up" : local.defaults.crosswork.device_management.network_devices.admin_state)], null)
  reachability_check = try(local.network_device_reachability_checks[try(each.value.reachability_check, local.defaults.crosswork.device_management.network_devices.reachability_check)], null)
  serial_number      = try(each.value.serial_number, local.defaults.crosswork.device_management.network_devices.serial_number, null)
  mac_address        = try(each.value.mac_address, local.defaults.crosswork.device_management.network_devices.mac_address, null)
  device_type        = try(local.network_device_types[try(each.value.device_type, local.defaults.crosswork.device_management.network_devices.device_type)], null)
  software_type      = try(each.value.software_type, local.defaults.crosswork.device_management.network_devices.software_type, null)
  software_version   = try(each.value.software_version, local.defaults.crosswork.device_management.network_devices.software_version, null)
  product_type       = try(each.value.product_type, local.defaults.crosswork.device_management.network_devices.product_type, null)
  syslog_format      = try(local.network_device_syslog_formats[try(each.value.syslog_format, local.defaults.crosswork.device_management.network_devices.syslog_format)], null)
  capabilities       = try(each.value.connectivity.capabilities, local.defaults.crosswork.device_management.network_devices.connectivity.capabilities, null)
  cli_cache_enabled  = try(each.value.cli_cache_enabled, local.defaults.crosswork.device_management.network_devices.cli_cache_enabled, null)
  encryption         = try(lower([for row in each.value.connectivity.protocols : row.encryption if row.protocol == "SNMP" && try(row.encryption, "NONE") != "NONE"][0]), null)
  connectivity = [for row in each.value.connectivity.protocols : {
    protocol                     = local.network_device_protocols[row.protocol]
    ip_address                   = row.ip_address
    prefix_length                = row.prefix_length
    port                         = try(row.port, lookup(local.network_device_default_ports, row.protocol, null))
    timeout                      = try(row.timeout, local.defaults.crosswork.device_management.network_devices.connectivity.protocols.timeout, null)
    encoding_type                = try(row.encoding_type, local.defaults.crosswork.device_management.network_devices.connectivity.protocols.encoding_type, null)
    trap_source_ip               = try(row.trap_source_ip, local.defaults.crosswork.device_management.network_devices.connectivity.protocols.trap_source_ip, null)
    disable_trap_community_check = try(row.disable_trap_community_check, local.defaults.crosswork.device_management.network_devices.connectivity.protocols.disable_trap_community_check, null)
  }]
  provider_profile                = try(crosswork_provider_profiles.provider_profile[each.value.providers.name].id, try(each.value.providers.name, null))
  isis_system_id                  = try(each.value.routing.isis_system_id, local.defaults.crosswork.device_management.network_devices.routing.isis_system_id, null)
  ospf_router_id                  = try(each.value.routing.ospf_router_id, local.defaults.crosswork.device_management.network_devices.routing.ospf_router_id, null)
  te_router_id                    = try(each.value.routing.te_router_id, local.defaults.crosswork.device_management.network_devices.routing.te_router_id, null)
  ipv6_router_id                  = try(each.value.routing.ipv6_router_id, local.defaults.crosswork.device_management.network_devices.routing.ipv6_router_id, null)
  telemetry_vrf                   = try(each.value.telemetry.vrf, local.defaults.crosswork.device_management.network_devices.telemetry.vrf, null)
  telemetry_source_interface      = try(each.value.telemetry.source_interface, local.defaults.crosswork.device_management.network_devices.telemetry.source_interface, null)
  telemetry_opt_out_of_mdt_config = try(each.value.telemetry.opt_out_of_mdt_config, local.defaults.crosswork.device_management.network_devices.telemetry.opt_out_of_mdt_config, null)
  location_building               = try(each.value.location.building, local.defaults.crosswork.device_management.network_devices.location.building, null)
  location_street                 = try(each.value.location.street, local.defaults.crosswork.device_management.network_devices.location.street, null)
  location_city                   = try(each.value.location.city, local.defaults.crosswork.device_management.network_devices.location.city, null)
  location_state                  = try(each.value.location.state, local.defaults.crosswork.device_management.network_devices.location.state, null)
  location_country                = try(each.value.location.country, local.defaults.crosswork.device_management.network_devices.location.country, null)
  location_region                 = try(each.value.location.region, local.defaults.crosswork.device_management.network_devices.location.region, null)
  location_zip                    = try(each.value.location.zip, local.defaults.crosswork.device_management.network_devices.location.zip, null)
  location_latitude               = try(each.value.location.latitude, local.defaults.crosswork.device_management.network_devices.location.latitude, null)
  location_longitude              = try(each.value.location.longitude, local.defaults.crosswork.device_management.network_devices.location.longitude, null)
  location_altitude               = try(each.value.location.altitude, local.defaults.crosswork.device_management.network_devices.location.altitude, null)
  # Unset leaves the tags of the device alone; a list, an empty one included, makes the device carry exactly those.
  tags = try(each.value.tags, null) == null ? null : [for tag in each.value.tags : {
    name = try(crosswork_tags.tag[tag].id, tag)
  }]

  # A device can change its own host name, so a later difference is not a change of the model.
  lifecycle {
    ignore_changes = [host_name]
  }
}
