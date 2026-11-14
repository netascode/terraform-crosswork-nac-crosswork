### DEVICE GROUPS ###

locals {
  device_groups = try(local.crosswork.device_management.device_groups, [])

  # The anchor is the built-in group that allows subgroups (All Locations), not the group without a parent: the Location
  # root refuses children.
  existing_device_groups = try(data.crosswork_groupings.device[0].items, [])
  device_group_anchor    = try([for group in local.existing_device_groups : group.id if group.discovery_type == "StaticSystem" && group.subgroups_allowed][0], null)

  # The model is a tree, but a resource cannot create from its own instances, so each level is one resource. Names are
  # only unique among the groups of one parent, so an entry is keyed by the names down to it, joined with "/" (an inner
  # "/" or "%" is escaped as %2F or %25). The datamodel validation limits the depth to 10.
  device_groups_level_1  = [for group in local.device_groups : { key = replace(replace(group.name, "%", "%25"), "/", "%2F"), name = group.name, description = try(group.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = null, groups = try(group.groups, []), devices = try(group.devices, []) }]
  device_groups_level_2  = flatten([for group in local.device_groups_level_1 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_3  = flatten([for group in local.device_groups_level_2 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_4  = flatten([for group in local.device_groups_level_3 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_5  = flatten([for group in local.device_groups_level_4 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_6  = flatten([for group in local.device_groups_level_5 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_7  = flatten([for group in local.device_groups_level_6 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_8  = flatten([for group in local.device_groups_level_7 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_9  = flatten([for group in local.device_groups_level_8 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])
  device_groups_level_10 = flatten([for group in local.device_groups_level_9 : [for child in group.groups : { key = "${group.key}/${replace(replace(child.name, "%", "%25"), "/", "%2F")}", name = child.name, description = try(child.description, local.defaults.crosswork.device_management.device_groups.description, null), parent = group.key, groups = try(child.groups, []), devices = try(child.devices, []) }]])

  # The ids of the groups of the model, by key, and the groups that list devices, at any level.
  device_group_ids = merge(
    { for key, group in crosswork_device_groups.level_1 : key => group.id },
    { for key, group in crosswork_device_groups.level_2 : key => group.id },
    { for key, group in crosswork_device_groups.level_3 : key => group.id },
    { for key, group in crosswork_device_groups.level_4 : key => group.id },
    { for key, group in crosswork_device_groups.level_5 : key => group.id },
    { for key, group in crosswork_device_groups.level_6 : key => group.id },
    { for key, group in crosswork_device_groups.level_7 : key => group.id },
    { for key, group in crosswork_device_groups.level_8 : key => group.id },
    { for key, group in crosswork_device_groups.level_9 : key => group.id },
    { for key, group in crosswork_device_groups.level_10 : key => group.id },
  )
  device_group_devices = merge([
    for level in [
      local.device_groups_level_1, local.device_groups_level_2, local.device_groups_level_3,
      local.device_groups_level_4, local.device_groups_level_5, local.device_groups_level_6,
      local.device_groups_level_7, local.device_groups_level_8, local.device_groups_level_9,
      local.device_groups_level_10,
    ] : { for group in level : group.key => group.devices if length(group.devices) > 0 }
  ]...)
}

# Read only when the model has groups, so a model without them needs no cluster at plan time. It gives the anchor.
data "crosswork_groupings" "device" {
  count      = length(local.device_groups) > 0 ? 1 : 0
  instance   = var.instance
  classifier = "LocationDevices"
}

resource "crosswork_device_groups" "level_1" {
  for_each    = { for group in local.device_groups_level_1 : group.key => { name = group.name, description = group.description } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = local.device_group_anchor

  lifecycle {
    precondition {
      condition     = local.device_group_anchor != null
      error_message = "Device group ${each.value.name}: the All Locations group was not found on this cluster."
    }
  }
}

resource "crosswork_device_groups" "level_2" {
  for_each    = { for group in local.device_groups_level_2 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_1[each.value.parent].id
}

resource "crosswork_device_groups" "level_3" {
  for_each    = { for group in local.device_groups_level_3 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_2[each.value.parent].id
}

resource "crosswork_device_groups" "level_4" {
  for_each    = { for group in local.device_groups_level_4 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_3[each.value.parent].id
}

resource "crosswork_device_groups" "level_5" {
  for_each    = { for group in local.device_groups_level_5 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_4[each.value.parent].id
}

resource "crosswork_device_groups" "level_6" {
  for_each    = { for group in local.device_groups_level_6 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_5[each.value.parent].id
}

resource "crosswork_device_groups" "level_7" {
  for_each    = { for group in local.device_groups_level_7 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_6[each.value.parent].id
}

resource "crosswork_device_groups" "level_8" {
  for_each    = { for group in local.device_groups_level_8 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_7[each.value.parent].id
}

resource "crosswork_device_groups" "level_9" {
  for_each    = { for group in local.device_groups_level_9 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_8[each.value.parent].id
}

resource "crosswork_device_groups" "level_10" {
  for_each    = { for group in local.device_groups_level_10 : group.key => { name = group.name, description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.value.name
  description = each.value.description
  parent_uuid = crosswork_device_groups.level_9[each.value.parent].id
}

# The devices of a group. A device is in one device group at a time, so listing it moves it out of its old group; a
# device that leaves a group goes back to Unassigned Devices.
resource "crosswork_assign_devices_to_device_group" "assignment" {
  for_each = local.device_group_devices
  instance = var.instance
  group_id = local.device_group_ids[each.key]
  devices  = [for device in each.value : crosswork_network_devices.network_device[device].id]
}
