### RESOURCE POOLS ###

locals {
  resource_pools = {
    for pool in try(local.crosswork.services.resource_pools, []) : pool.name => {
      name        = pool.name
      range_start = pool.range_start
      range_end   = pool.range_end
    }
  }
}

resource "crosswork_resource_pools" "resource_pool" {
  for_each    = local.resource_pools
  instance    = var.instance
  name        = each.value.name
  range_start = each.value.range_start
  range_end   = each.value.range_end
}
