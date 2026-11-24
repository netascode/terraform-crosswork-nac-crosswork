### PORT GROUPS SHARED ###

locals {
  port_groups = try(local.crosswork.device_management.port_groups, [])
}

### PORT GROUPS ###

locals {
  # Port groups sit directly under the built-in User Defined group (StaticSystem, takes subgroups) and cannot nest
  existing_port_groups = try(data.crosswork_groupings.port[0].items, [])
  port_group_root      = try([for group in local.existing_port_groups : group.id if group.discovery_type == "StaticSystem" && group.subgroups_allowed][0], null)
}

# Read only when the model has port groups, so a model without them needs no cluster at plan time. It gives the root.
data "crosswork_groupings" "port" {
  count      = length(local.port_groups) > 0 ? 1 : 0
  instance   = var.instance
  classifier = "UserDefinedPorts"
}

# The name is the key: the names of the port groups are unique without regard to case, and all of them share one parent.
resource "crosswork_port_groups" "port_group" {
  for_each    = { for group in local.port_groups : group.name => group }
  instance    = var.instance
  name        = each.value.name
  description = try(each.value.description, local.defaults.crosswork.device_management.port_groups.description, null)
  parent_uuid = local.port_group_root

  lifecycle {
    precondition {
      condition     = local.port_group_root != null
      error_message = "Port group ${each.key}: the User Defined port group root was not found on this cluster."
    }
  }
}

### PORT GROUP PORTS ###

locals {
  # The groups that list ports. A name is the key, as it is unique among the port groups.
  port_group_ports = { for group in local.port_groups : group.name => group.ports if length(try(group.ports, [])) > 0 }
}

# The ports of a group. A port exists only once Crosswork has collected its device, so a device added in the same run
# has no ports yet: the first apply fails until it is collected, and a second apply assigns them.
resource "crosswork_assign_ports_to_port_group" "assignment" {
  for_each = local.port_group_ports
  instance = var.instance
  group_id = crosswork_port_groups.port_group[each.key].id
  ports    = [for port in each.value : { device = crosswork_network_devices.network_device[port.device].id, port_name = port.port_name }]
}

### PORT GROUP RULES ###

locals {
  # The groups that have a dynamic rule. The model is an OR of entries that are each an AND of conditions; Crosswork
  # keeps one flat list where AND binds tighter than OR, so the first condition of an entry is joined with "or", the
  # others with "and". A speed has no space in the model (100Gbps) and one for Crosswork.
  port_group_rules = {
    for group in local.port_groups : group.name => flatten([
      for entry_index, entry in group.dynamic_rules : [
        for condition_index, condition in entry.conditions : {
          attribute        = condition.attribute
          operator         = condition.operator
          value            = try(condition.attribute == "speed" ? replace(condition.value, "/^([0-9]+)([A-Za-z]+)$/", "$1 $2") : condition.value, null)
          logical_operator = entry_index == 0 && condition_index == 0 ? null : (condition_index == 0 ? "or" : "and")
        }
      ]
    ]) if length(try(group.dynamic_rules, [])) > 0
  }
}

resource "crosswork_port_groups_rules" "rule" {
  for_each   = local.port_group_rules
  instance   = var.instance
  group_id   = crosswork_port_groups.port_group[each.key].id
  name       = each.key
  conditions = each.value
}
