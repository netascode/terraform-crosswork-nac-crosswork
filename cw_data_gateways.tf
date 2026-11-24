### DATA GATEWAY SHARED ###

locals {
  data_gateways_pools = try(local.crosswork.data_gateways.pools, [])
}

### DATA GATEWAY POOLS ###

locals {
  # The instances (the enrolled virtual machines) are not declared in the model; the cluster checks their names.
  data_gateway_instance_ids = { for instance in try(data.crosswork_data_gateway_instances.instance[0].items, []) : instance.name => instance.id }

  data_gateway_unknown_instances = {
    for pool in local.data_gateways_pools : pool.name => [for name in pool.instances : name if !contains(keys(local.data_gateway_instance_ids), name)]
  }
}

# Read only when the model has pools, so a model without them needs no cluster at plan time.
data "crosswork_data_gateway_instances" "instance" {
  count    = length(local.data_gateways_pools) > 0 ? 1 : 0
  instance = var.instance
}

# A pool puts instances behind virtual IPs, one data gateway for each. The name is the key, as pool names are unique.
resource "crosswork_data_gateway_pools" "pool" {
  for_each              = { for pool in local.data_gateways_pools : pool.name => pool }
  instance              = var.instance
  name                  = each.value.name
  description           = try(each.value.description, local.defaults.crosswork.data_gateways.pools.description, null)
  virtual_ips           = each.value.virtual_ips
  prefix_length         = each.value.prefix_length
  spares                = try(each.value.spares, local.defaults.crosswork.data_gateways.pools.spares, null)
  instances             = [for name in each.value.instances : lookup(local.data_gateway_instance_ids, name, name)]
  cdg_readiness_timeout = try(each.value.cdg_readiness_timeout, local.defaults.crosswork.data_gateways.pools.cdg_readiness_timeout, null)

  # The names of the instances can only be checked on the cluster, so this is the one check a rule cannot make.
  lifecycle {
    precondition {
      condition     = length(local.data_gateway_unknown_instances[each.key]) == 0
      error_message = "Data gateway pool ${each.key}: these instances are not enrolled on the cluster: ${join(", ", local.data_gateway_unknown_instances[each.key])}."
    }
  }
}

### DATA GATEWAY DEVICES ###

locals {
  # The data gateways of the pools, named by Crosswork: one for each virtual IP, <pool name>-<n> with n from 1.
  # The name is the key: devices name their data gateway by it.
  data_gateway_name_entries = flatten([
    for pool in local.data_gateways_pools : [
      for index, address in pool.virtual_ips : {
        key   = format("%s-%d", pool.name, index + 1)
        pool  = pool.name
        index = index
      }
    ]
  ])

  data_gateway_names = { for entry in local.data_gateway_name_entries : entry.key => { pool = entry.pool, index = entry.index } }

  # The devices of each data gateway, by the name the devices give it.
  data_gateway_devices = {
    for gateway in distinct([for device in local.network_devices : device.data_gateway if try(device.data_gateway, null) != null]) :
    gateway => [for device in local.network_devices : device.name if try(device.data_gateway, null) == gateway]
  }
}

# One resource for each data gateway that has devices. On a destroy the devices are detached before the pool is deleted,
# which the controller needs.
resource "crosswork_assign_devices_to_data_gateway" "gateway" {
  for_each        = local.data_gateway_devices
  instance        = var.instance
  data_gateway_id = try(crosswork_data_gateway_pools.pool[local.data_gateway_names[each.key].pool].data_gateway_ids[local.data_gateway_names[each.key].index], null)
  devices         = [for name in each.value : crosswork_network_devices.network_device[name].id]
}

### DATA GATEWAY DESTINATIONS ###

locals {
  data_gateways_destinations = try(local.crosswork.data_gateways.destinations, [])
}

resource "crosswork_data_gateway_destinations" "destination" {
  for_each           = { for destination in local.data_gateways_destinations : destination.name => destination }
  instance           = var.instance
  name               = each.value.name
  data_source        = each.value.data_source
  server_type        = each.value.server_type
  compression_method = each.value.compression_method
  encoding           = try(each.value.encoding, local.defaults.crosswork.data_gateways.destinations.encoding, null)
  dispatch_type      = try(each.value.dispatch_type, local.defaults.crosswork.data_gateways.destinations.dispatch_type, null)
  max_message_size   = try(each.value.max_message_size, local.defaults.crosswork.data_gateways.destinations.max_message_size, null)
  buffer_memory      = try(each.value.buffer_memory, local.defaults.crosswork.data_gateways.destinations.buffer_memory, null)
  batch_size         = try(each.value.batch_size, local.defaults.crosswork.data_gateways.destinations.batch_size, null)
  linger_time        = try(each.value.linger_time, local.defaults.crosswork.data_gateways.destinations.linger_time, null)
  request_timeout    = try(each.value.request_timeout, local.defaults.crosswork.data_gateways.destinations.request_timeout, null)
  secure             = try(each.value.secure, local.defaults.crosswork.data_gateways.destinations.secure, null)
  auth_type          = try(each.value.auth_type, local.defaults.crosswork.data_gateways.destinations.auth_type, null)
  collectors = try(length(each.value.collectors) == 0, true) ? null : [for collector in each.value.collectors : {
    name            = collector.name
    buffer_memory   = try(collector.buffer_memory, local.defaults.crosswork.data_gateways.destinations.collectors.buffer_memory, null)
    batch_size      = try(collector.batch_size, local.defaults.crosswork.data_gateways.destinations.collectors.batch_size, null)
    linger_time     = try(collector.linger_time, local.defaults.crosswork.data_gateways.destinations.collectors.linger_time, null)
    request_timeout = try(collector.request_timeout, local.defaults.crosswork.data_gateways.destinations.collectors.request_timeout, null)
  }]
  # A connection is an address with a prefix length or a host name with a domain name, so there is no default for them.
  connections = [for connection in each.value.connections : {
    address       = try(connection.address, null)
    prefix_length = try(connection.prefix_length, null)
    host_name     = try(connection.host_name, null)
    domain_name   = try(connection.domain_name, null)
    port          = connection.port
  }]
}

### DATA GATEWAY SETTINGS ###

locals {
  data_gateways_global_parameters       = try(local.crosswork.data_gateways.global_parameters, null)
  data_gateways_resource_configurations = try(local.crosswork.data_gateways.resource_configurations, null)
}

resource "crosswork_data_gateway_global_parameters" "global_parameters" {
  count                 = local.data_gateways_global_parameters != null ? 1 : 0
  instance              = var.instance
  cli_sessions          = try(local.data_gateways_global_parameters.cli_sessions, local.defaults.crosswork.data_gateways.global_parameters.cli_sessions, null)
  ssh_session_timeout   = try(local.data_gateways_global_parameters.ssh_session_timeout, local.defaults.crosswork.data_gateways.global_parameters.ssh_session_timeout, null)
  snmp_trap_port        = try(local.data_gateways_global_parameters.snmp_trap_port, local.defaults.crosswork.data_gateways.global_parameters.snmp_trap_port, null)
  syslog_udp_port       = try(local.data_gateways_global_parameters.syslog_udp_port, local.defaults.crosswork.data_gateways.global_parameters.syslog_udp_port, null)
  syslog_tcp_port       = try(local.data_gateways_global_parameters.syslog_tcp_port, local.defaults.crosswork.data_gateways.global_parameters.syslog_tcp_port, null)
  syslog_tls_port       = try(local.data_gateways_global_parameters.syslog_tls_port, local.defaults.crosswork.data_gateways.global_parameters.syslog_tls_port, null)
  resync_snmpv3_details = try(local.data_gateways_global_parameters.resync_snmpv3_details, local.defaults.crosswork.data_gateways.global_parameters.resync_snmpv3_details, null)
}

resource "crosswork_data_gateway_resource_configuration" "resource_configurations" {
  count          = local.data_gateways_resource_configurations != null ? 1 : 0
  instance       = var.instance
  update_timeout = try(local.data_gateways_resource_configurations.update_timeout, local.defaults.crosswork.data_gateways.resource_configurations.update_timeout, null)
  collectors = [for collector in try(local.data_gateways_resource_configurations.collectors, []) : {
    name    = collector.name
    memory  = try(collector.memory, local.defaults.crosswork.data_gateways.resource_configurations.collectors.memory, null)
    enabled = try(collector.enabled, local.defaults.crosswork.data_gateways.resource_configurations.collectors.enabled, null)
  }]
}

### DATA GATEWAY COLLECTION JOBS ###

locals {
  data_gateways_collection_jobs         = try(local.crosswork.data_gateways.collection_jobs.jobs, [])
  data_gateways_collection_jobs_cadence = try(local.crosswork.data_gateways.collection_jobs.cadence, null)
  collection_jobs_cadence_defaults      = local.defaults.crosswork.data_gateways.collection_jobs.cadence
  # The model gives hours and minutes, the resource takes seconds.
  collection_jobs_cadence_intervals = {
    for key in ["reachability_check", "snmp_check", "te_tunnel_id", "show_clock"] : key => (
      try(local.data_gateways_collection_jobs_cadence[key], null) != null ? local.data_gateways_collection_jobs_cadence[key] : local.collection_jobs_cadence_defaults[key]
    )
  }
  collection_jobs_cadence_seconds = {
    for key, interval in local.collection_jobs_cadence_intervals : key => (interval.hours * 60 + interval.minutes) * 60
  }
}

# Crosswork needs all four values in every change, so the module always sends all four.
resource "crosswork_collection_jobs_cadence" "cadence" {
  count              = local.data_gateways_collection_jobs_cadence != null ? 1 : 0
  instance           = var.instance
  reachability_check = local.collection_jobs_cadence_seconds["reachability_check"]
  snmp_check         = local.collection_jobs_cadence_seconds["snmp_check"]
  te_tunnel_id       = local.collection_jobs_cadence_seconds["te_tunnel_id"]
  show_clock         = local.collection_jobs_cadence_seconds["show_clock"]
}

# The application id and the context id are the key of a job. Crosswork lets a destination, a device or a tag be deleted
# while a job uses it, so the job depends on all of them: created after them, deleted first on a destroy. It does not
# depend on the data gateway attachments.
resource "crosswork_collection_jobs" "collection_job" {
  for_each       = { for job in local.data_gateways_collection_jobs : format("%s/%s", job.application_id, job.context_id) => job }
  instance       = var.instance
  application_id = each.value.application_id
  context_id     = each.value.context_id
  collector_type = each.value.collector_type
  devices        = try(each.value.devices, null)
  device_tag     = try(each.value.device_tag, null)
  destination    = each.value.destination
  cli_sensors = try(length(each.value.cli_sensors) == 0, true) ? null : [for sensor in each.value.cli_sensors : {
    command = sensor.command
    cadence = sensor.cadence
    topic   = sensor.topic
  }]
  snmp_sensors = try(length(each.value.snmp_sensors) == 0, true) ? null : [for sensor in each.value.snmp_sensors : {
    oid       = sensor.oid
    operation = sensor.operation
    cadence   = sensor.cadence
    topic     = sensor.topic
  }]

  depends_on = [
    crosswork_data_gateway_destinations.destination,
    crosswork_network_devices.network_device,
    crosswork_tags.tag,
  ]
}
