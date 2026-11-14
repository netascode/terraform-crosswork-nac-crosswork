locals {
  roles = try(local.crosswork.administration.roles, [])

  # The access names of the datamodel and the letters the provider takes.
  access_levels = {
    read              = "R"
    write             = "W"
    delete            = "D"
    read-write        = "RW"
    read-delete       = "RD"
    write-delete      = "WD"
    read-write-delete = "RWD"
  }

  # Names are normalized the same way in the model and the catalog: lower case, each run of other characters becomes one
  # dash, trimmed. The catalog of the cluster maps API and task ids by normalized name.
  catalog = try(data.crosswork_role_catalog.catalog[0], {
    apis                 = []
    tasks                = []
    task_api_permissions = []
  })
  api_keys = { for api in local.catalog.apis : api.id => {
    category = trim(replace(lower(api.category), "/[^a-z0-9]+/", "-"), "-")
    row      = trim(replace(lower(api.name), "/[^a-z0-9]+/", "-"), "-")
  } }
  task_keys = { for task in local.catalog.tasks : task.id => trim(replace(lower(task.name), "/[^a-z0-9]+/", "-"), "-") }

  # Entries of each role resolved to catalog ids.
  role_api_entries = { for role in local.roles : role.name => [for entry in try(role.api_permissions, []) : {
    label  = try(entry.category, null) != null ? "category: ${entry.category}" : "task: ${entry.task}"
    access = local.access_levels[entry.access]
    ids = try(entry.category, null) != null ? (
      tolist([for id, key in local.api_keys : id if key.category == trim(replace(lower(entry.category), "/[^a-z0-9]+/", "-"), "-")])
      ) : (
      tolist([for id, key in local.api_keys : id if key.row == trim(replace(lower(entry.task), "/[^a-z0-9]+/", "-"), "-")])
    )
  }] }
  role_task_entries = { for role in local.roles : role.name => [for name in try(role.task_permissions, []) : {
    label = name
    ids   = tolist([for id, key in local.task_keys : id if key == trim(replace(lower(name), "/[^a-z0-9]+/", "-"), "-")])
  }] }
  role_tasks = { for role in local.roles : role.name => distinct(flatten([for entry in local.role_task_entries[role.name] : entry.ids])) }

  # Permissions sent to the provider.
  # Crosswork rejects a task whose APIs the role lacks, so the APIs its tasks need are added.
  role_api_requests = { for role in local.roles : role.name => concat(
    flatten([for entry in local.role_api_entries[role.name] : [for id in entry.ids : { id = id, level = entry.access }]]),
    flatten([for task in local.role_tasks[role.name] : [for need in local.catalog.task_api_permissions : { id = need.api_id, level = need.access } if need.task_id == task]])
  ) }
  # One level per API id: the letters of all its requests, in the order R, W, D.
  role_api_permissions = { for role in local.roles : role.name => {
    for id in distinct([for request in local.role_api_requests[role.name] : request.id]) :
    id => join("", [for letter in ["R", "W", "D"] : letter if anytrue([for request in local.role_api_requests[role.name] : request.id == id && strcontains(request.level, letter)])])
  } }

  # Entries without a match on the cluster, reported by the preconditions of the role.
  role_unknown_api_entries  = { for role in local.roles : role.name => [for entry in local.role_api_entries[role.name] : entry.label if length(entry.ids) == 0] }
  role_unknown_task_entries = { for role in local.roles : role.name => [for entry in local.role_task_entries[role.name] : entry.label if length(entry.ids) == 0] }
}

# Read only when the model has roles, so a model without them needs no cluster at plan time.
data "crosswork_role_catalog" "catalog" {
  count    = length(local.roles) > 0 ? 1 : 0
  instance = var.instance
}

resource "crosswork_roles" "role" {
  for_each         = { for role in local.roles : role.name => role }
  instance         = var.instance
  name             = each.value.name
  api_permissions  = local.role_api_permissions[each.key]
  task_permissions = length(local.role_tasks[each.key]) > 0 ? toset(local.role_tasks[each.key]) : null

  lifecycle {
    precondition {
      condition     = length(local.role_unknown_api_entries[each.key]) == 0
      error_message = "Role ${each.key}: api_permissions has entries that do not exist on this cluster: ${join(", ", local.role_unknown_api_entries[each.key])}. This cluster does not offer these permissions."
    }
    precondition {
      condition     = length(local.role_unknown_task_entries[each.key]) == 0
      error_message = "Role ${each.key}: task_permissions has tasks that do not exist on this cluster: ${join(", ", local.role_unknown_task_entries[each.key])}. This cluster does not offer these permissions."
    }
  }
}
