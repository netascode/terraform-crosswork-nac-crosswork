### USERS ###

locals {
  users = try(local.crosswork.administration.users, [])
}

# A user lists device access group names; the ids come from cw_device_access_groups.tf.
resource "crosswork_users" "user" {
  for_each            = { for user in local.users : user.username => user }
  instance            = var.instance
  username            = each.value.username
  first_name          = each.value.first_name
  last_name           = each.value.last_name
  policy_id           = each.value.role
  password            = try(each.value.password_version, null) == null ? sensitive(each.value.password) : null
  password_wo         = try(each.value.password_version, null) != null ? sensitive(each.value.password) : null
  password_wo_version = try(each.value.password_version, null)
  device_access_groups = [for name in each.value.device_access_groups : {
    uuid        = local.device_access_group_ids[name]
    domain_name = name
  }]

  depends_on = [crosswork_roles.role]
}

### LOCKED USERS ###

resource "crosswork_lock_users" "lock_user" {
  for_each = { for user in local.users : user.username => user if try(user.locked, local.defaults.crosswork.administration.users.locked, false) }
  instance = var.instance
  username = each.value.username

  depends_on = [crosswork_users.user]
}
