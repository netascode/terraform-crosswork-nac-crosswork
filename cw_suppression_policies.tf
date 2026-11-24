### SUPPRESSION POLICIES ###

locals {
  suppression_policies = { for policy in try(local.crosswork.alerts.suppression_policies, []) : policy.name => policy }

  # A group of the model is written as the path of its names (below All Locations), a built-in group by its absolute path
  suppression_policy_group_ids = {
    for name, policy in local.suppression_policies : name => try(
      policy.device_group == null ? null : coalesce(
        try(local.device_group_ids[join("/", [for segment in split("/", policy.device_group) : replace(segment, "%", "%25")])], null),
        try(local.builtin_device_group_ids[policy.device_group], null),
      ),
      null
    )
  }

  suppression_policy_actions = {
    alarms            = "suppressAlarm"
    alarms_and_events = "suppressEvent"
  }
}

resource "crosswork_suppression_policies" "suppression" {
  for_each      = local.suppression_policies
  instance      = var.instance
  name          = each.value.name
  description   = try(coalesce(each.value.description), null)
  action        = local.suppression_policy_actions[each.value.suppress]
  device_groups = local.suppression_policy_group_ids[each.key] == null ? null : [local.suppression_policy_group_ids[each.key]]
  criteria      = "eventType in [${join(",", sort(each.value.event_types))}]"

  lifecycle {
    precondition {
      condition     = try(each.value.device_group, null) == null || local.suppression_policy_group_ids[each.key] != null
      error_message = "Suppression policy ${each.value.name}: the device group ${try(each.value.device_group, "")} is neither a device group of the model nor a built-in group of the cluster."
    }
  }
}
