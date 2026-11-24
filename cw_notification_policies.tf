### SYSTEM NOTIFICATION POLICIES ###

locals {
  # One list holds both types, and the name is unique across them
  system_notification_policies = { for policy in try(local.crosswork.alerts.notification_policies, []) : policy.name => policy if policy.type == "system" }
}

resource "crosswork_system_notification_policies" "system" {
  for_each         = local.system_notification_policies
  instance         = var.instance
  name             = each.value.name
  description      = try(each.value.description, local.defaults.crosswork.alerts.notification_policies.description, null)
  criteria         = each.value.criteria
  trap_receivers   = try(length(each.value.trap_receivers) == 0, true) ? null : [for name in each.value.trap_receivers : { name = crosswork_trap_destination.trap[name].name }]
  syslog_receivers = try(length(each.value.syslog_receivers) == 0, true) ? null : [for name in each.value.syslog_receivers : { name = crosswork_syslog_destination.syslog[name].name }]
}

### DEVICE NOTIFICATION POLICIES ###

locals {
  device_notification_policies = { for policy in try(local.crosswork.alerts.notification_policies, []) : policy.name => policy if policy.type == "device" }

  # The built-in groups of the controller (Location, Location/All Locations, Location/All Locations/Unassigned Devices) by their full path
  builtin_device_group_ids = { for group in local.existing_device_groups : group.path => group.id if group.discovery_type == "StaticSystem" }

  # A group of the model is written as the path of its names (below All Locations), a built-in group by its absolute path
  device_notification_policy_group_ids = {
    for name, policy in local.device_notification_policies : name => try(
      policy.device_group == null ? null : coalesce(
        try(local.device_group_ids[join("/", [for segment in split("/", policy.device_group) : replace(segment, "%", "%25")])], null),
        try(local.builtin_device_group_ids[policy.device_group], null),
      ),
      null
    )
  }
}

resource "crosswork_device_notification_policies" "device" {
  for_each         = local.device_notification_policies
  instance         = var.instance
  name             = each.value.name
  description      = try(each.value.description, local.defaults.crosswork.alerts.notification_policies.description, null)
  device_group     = local.device_notification_policy_group_ids[each.key]
  filters          = [for filter in each.value.filters : { severities = try(length(filter.severities) == 0, true) ? null : filter.severities, category = try(filter.category, null), events = try(length(filter.events) == 0, true) ? null : filter.events }]
  trap_receivers   = try(length(each.value.trap_receivers) == 0, true) ? null : [for name in each.value.trap_receivers : { name = crosswork_trap_destination.trap[name].name }]
  syslog_receivers = try(length(each.value.syslog_receivers) == 0, true) ? null : [for name in each.value.syslog_receivers : { name = crosswork_syslog_destination.syslog[name].name }]

  lifecycle {
    precondition {
      condition     = try(each.value.device_group, null) == null || local.device_notification_policy_group_ids[each.key] != null
      error_message = "Device notification policy ${each.value.name}: the device group ${try(each.value.device_group, "")} is neither a device group of the model nor a built-in group of the cluster."
    }
  }
}
