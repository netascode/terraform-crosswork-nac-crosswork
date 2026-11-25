### DEMAND MATRIX ###

locals {
  demand_matrix_domains = { for domain in try(local.crosswork.services.demand_matrix.domains, []) : tostring(domain.domain_id) => domain }
}

resource "crosswork_demand_matrix_global_configuration" "global_configuration" {
  count                  = try(local.crosswork.services.demand_matrix.global, null) != null ? 1 : 0
  instance               = var.instance
  computation_cadence    = try(local.crosswork.services.demand_matrix.global.computation_cadence_minutes, local.defaults.crosswork.services.demand_matrix.global.computation_cadence_minutes, null)
  minimum_demand_traffic = try(local.crosswork.services.demand_matrix.global.minimum_demand_traffic_kbps, local.defaults.crosswork.services.demand_matrix.global.minimum_demand_traffic_kbps, null)
  debug_mode             = try(local.crosswork.services.demand_matrix.global.debug_mode, local.defaults.crosswork.services.demand_matrix.global.debug_mode, null)
  debug_max_plan_files   = try(local.crosswork.services.demand_matrix.global.debug_max_plan_files, local.defaults.crosswork.services.demand_matrix.global.debug_max_plan_files, null)
}

resource "crosswork_demand_matrix_domain" "domain" {
  for_each  = local.demand_matrix_domains
  instance  = var.instance
  domain_id = each.key
  enable    = try(each.value.enable, local.defaults.crosswork.services.demand_matrix.domains.enable, null)

  depends_on = [crosswork_demand_matrix_global_configuration.global_configuration]
}
