### DEVICE ACCESS GROUPS SHARED ###

locals {
  device_access_groups = try(local.crosswork.administration.device_access_groups, [])
  # The root is the built-in (StaticSystem) group that takes subgroups; every top-level group is created under it.
  existing_device_access_groups = try(data.crosswork_groupings.device_access[0].items, [])
  builtin_device_access_groups  = [for group in local.existing_device_access_groups : group if group.discovery_type == "StaticSystem"]
  # The model is a tree, one resource for each level. Names are unique across the whole tree, so a name is the key.
  device_access_groups_level_1  = [for group in local.device_access_groups : { name = group.name, description = try(group.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = null, subgroups = try(group.subgroups, []), devices = try(group.devices, []) }]
  device_access_groups_level_2  = flatten([for group in local.device_access_groups_level_1 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_3  = flatten([for group in local.device_access_groups_level_2 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_4  = flatten([for group in local.device_access_groups_level_3 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_5  = flatten([for group in local.device_access_groups_level_4 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_6  = flatten([for group in local.device_access_groups_level_5 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_7  = flatten([for group in local.device_access_groups_level_6 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_8  = flatten([for group in local.device_access_groups_level_7 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_9  = flatten([for group in local.device_access_groups_level_8 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_groups_level_10 = flatten([for group in local.device_access_groups_level_9 : [for child in group.subgroups : { name = child.name, description = try(child.description, local.defaults.crosswork.administration.device_access_groups.description, null), parent = group.name, subgroups = try(child.subgroups, []), devices = try(child.devices, []) }]])
  device_access_group_ids = merge(
    { for group in local.builtin_device_access_groups : group.name => group.id },
    { for name, group in crosswork_device_access_groups.level_1 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_2 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_3 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_4 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_5 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_6 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_7 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_8 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_9 : name => group.id },
    { for name, group in crosswork_device_access_groups.level_10 : name => group.id },
  )
}

### DEVICE ACCESS GROUPS ###

locals {
  device_access_group_root = try([for group in local.builtin_device_access_groups : group.id if group.subgroups_allowed][0], null)
}

data "crosswork_groupings" "device_access" {
  count      = length(local.device_access_groups) + length(local.users) > 0 ? 1 : 0
  instance   = var.instance
  classifier = "DeviceAccess"
}

resource "crosswork_device_access_groups" "level_1" {
  for_each    = { for group in local.device_access_groups_level_1 : group.name => { description = group.description } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = local.device_access_group_root

  lifecycle {
    precondition {
      condition     = local.device_access_group_root != null
      error_message = "Device access group ${each.key}: the root device access group was not found on this cluster."
    }
  }
}

resource "crosswork_device_access_groups" "level_2" {
  for_each    = { for group in local.device_access_groups_level_2 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_1[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_3" {
  for_each    = { for group in local.device_access_groups_level_3 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_2[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_4" {
  for_each    = { for group in local.device_access_groups_level_4 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_3[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_5" {
  for_each    = { for group in local.device_access_groups_level_5 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_4[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_6" {
  for_each    = { for group in local.device_access_groups_level_6 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_5[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_7" {
  for_each    = { for group in local.device_access_groups_level_7 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_6[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_8" {
  for_each    = { for group in local.device_access_groups_level_8 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_7[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_9" {
  for_each    = { for group in local.device_access_groups_level_9 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_8[each.value.parent].id
}

resource "crosswork_device_access_groups" "level_10" {
  for_each    = { for group in local.device_access_groups_level_10 : group.name => { description = group.description, parent = group.parent } }
  instance    = var.instance
  name        = each.key
  description = each.value.description
  parent_uuid = crosswork_device_access_groups.level_9[each.value.parent].id
}

### DEVICE ACCESS GROUP DEVICES ###

locals {
  # The groups that list devices, at any level. A name is the key, as it is unique across the whole tree.
  device_access_group_devices = merge([
    for level in [
      local.device_access_groups_level_1, local.device_access_groups_level_2, local.device_access_groups_level_3,
      local.device_access_groups_level_4, local.device_access_groups_level_5, local.device_access_groups_level_6,
      local.device_access_groups_level_7, local.device_access_groups_level_8, local.device_access_groups_level_9,
      local.device_access_groups_level_10,
    ] : { for group in level : group.name => group.devices if length(group.devices) > 0 }
  ]...)
}

resource "crosswork_assign_devices_to_access_group" "assignment" {
  for_each = local.device_access_group_devices
  instance = var.instance
  group_id = local.device_access_group_ids[each.key]
  devices  = [for device in each.value : crosswork_network_devices.network_device[device].id]

  depends_on = [crosswork_assign_devices_to_device_group.assignment]
}
