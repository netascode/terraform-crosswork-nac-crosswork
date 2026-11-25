### LOCAL CONGESTION MITIGATION ###

locals {
  lcm_domains  = { for domain in try(local.crosswork.services.local_congestion_mitigation.domains, []) : tostring(domain.domain_id) => domain }
  lcm_defaults = local.defaults.crosswork.services.local_congestion_mitigation.domains
  lcm_adjacency_hop_type = {
    "protected"             = "PROTECTED"
    "protected-preferred"   = "PROTECTED_PREFERRED"
    "unprotected"           = "UNPROTECTED"
    "unprotected-preferred" = "UNPROTECTED_PREFERRED"
  }
  lcm_operation_mode = {
    "automated" = "AUTOMATED"
    "manual"    = "MANUAL"
  }
  lcm_objective = {
    "min-delay"      = "MIN_DELAY"
    "min-igp-metric" = "MIN_IGP_METRIC"
    "min-te-metric"  = "MIN_TE_METRIC"
  }
  # The domains that give interfaces their own threshold; a domain without rows has no resource, and removing its rows destroys it.
  lcm_interface_thresholds = { for id, domain in local.lcm_domains : id => domain.interface_thresholds if length(try(domain.interface_thresholds, [])) > 0 }
  lcm_include_all_interfaces = {
    "all"      = true
    "selected" = false
  }
}

# A domain is created by the controller: the resource writes the configuration of an existing domain, and a destroy writes the defaults back.
resource "crosswork_local_congestion_mitigation" "local_congestion_mitigation" {
  for_each                             = local.lcm_domains
  instance                             = var.instance
  domain_id                            = each.key
  enable                               = try(each.value.basic.enable, local.lcm_defaults.basic.enable, null)
  color                                = try(each.value.basic.color, local.lcm_defaults.basic.color, null)
  utilization_threshold                = try(each.value.basic.utilization_threshold_percent, local.lcm_defaults.basic.utilization_threshold_percent, null)
  utilization_hold_margin              = try(each.value.basic.utilization_hold_margin_percent, local.lcm_defaults.basic.utilization_hold_margin_percent, null)
  delete_lsps                          = try(each.value.basic.delete_tactical_sr_policies_when_disabled, local.lcm_defaults.basic.delete_tactical_sr_policies_when_disabled, null)
  profile_id                           = try(each.value.basic.profile_id, local.lcm_defaults.basic.profile_id, null)
  congestion_check_interval            = try(each.value.basic.congestion_check_interval_seconds, local.lcm_defaults.basic.congestion_check_interval_seconds, null)
  max_tte_group                        = try(each.value.basic.max_lcm_policies_per_set, local.lcm_defaults.basic.max_lcm_policies_per_set, null)
  include_all_interfaces               = try(local.lcm_include_all_interfaces[try(each.value.basic.monitored_interfaces, local.lcm_defaults.basic.monitored_interfaces)], null)
  description                          = try(each.value.basic.description, local.lcm_defaults.basic.description, null)
  auto_repair_solution                 = try(each.value.advanced.auto_repair_solution, local.lcm_defaults.advanced.auto_repair_solution, null)
  stay_in_area                         = try(each.value.advanced.stay_in_area, local.lcm_defaults.advanced.stay_in_area, null)
  adjacency_hop_type                   = try(local.lcm_adjacency_hop_type[try(each.value.advanced.adjacency_hop_type, local.lcm_defaults.advanced.adjacency_hop_type)], null)
  operation_mode                       = try(local.lcm_operation_mode[try(each.value.advanced.operation_mode, local.lcm_defaults.advanced.operation_mode)], null)
  objective                            = try(local.lcm_objective[try(each.value.advanced.optimization_objective, local.lcm_defaults.advanced.optimization_objective)], null)
  pce_dispatch_timeout                 = try(each.value.advanced.deployment_timeout_seconds, local.lcm_defaults.advanced.deployment_timeout_seconds, null)
  congestion_check_suspension_interval = try(each.value.advanced.congestion_check_suspension_interval_seconds, local.lcm_defaults.advanced.congestion_check_suspension_interval_seconds, null)
  overprovision_factor                 = try(each.value.advanced.over_provisioning_factor_percent, local.lcm_defaults.advanced.over_provisioning_factor_percent, null)
  uneven_ecmp_traffic_threshold        = try(each.value.advanced.uneven_ecmp_traffic_threshold_percent, local.lcm_defaults.advanced.uneven_ecmp_traffic_threshold_percent, null)
  throttle_mode_threshold              = try(each.value.advanced.throttle_mode_threshold, local.lcm_defaults.advanced.throttle_mode_threshold, null)
  history_retention_time               = try(each.value.advanced.history_retention_days, local.lcm_defaults.advanced.history_retention_days, null)
  debug_opt                            = try(each.value.advanced.debug_optimizer, local.lcm_defaults.advanced.debug_optimizer, null)
  debug_opt_max_files                  = try(each.value.advanced.debug_optimizer_max_files, local.lcm_defaults.advanced.debug_optimizer_max_files, null)
  # An empty list or map is sent as unset: the controller replaces the whole configuration, so a missing list is empty.
  affinity_include_any = try(length(each.value.advanced.affinity.include_any) == 0, true) ? null : [
    for name in each.value.advanced.affinity.include_any : tostring(crosswork_te_link_affinity.te_link_affinity[name].bit_position)
  ]
  affinity_exclude_any = try(length(each.value.advanced.affinity.exclude_any) == 0, true) ? null : [
    for name in each.value.advanced.affinity.exclude_any : tostring(crosswork_te_link_affinity.te_link_affinity[name].bit_position)
  ]
  affinity_include_all = try(length(each.value.advanced.affinity.include_all) == 0, true) ? null : [
    for name in each.value.advanced.affinity.include_all : tostring(crosswork_te_link_affinity.te_link_affinity[name].bit_position)
  ]
  node_tag_max_sid_depth = try(length(each.value.advanced.maximum_segment_hops) == 0, true) ? null : {
    for hop in each.value.advanced.maximum_segment_hops : hop.tag => tostring(hop.msd)
  }

  depends_on = [
    crosswork_tags.tag,
    crosswork_network_devices.network_device,
    crosswork_golden_config_jobs.job_9,
  ]
}

resource "crosswork_local_congestion_mitigation_interface_thresholds" "local_congestion_mitigation_interface_thresholds" {
  for_each  = local.lcm_interface_thresholds
  instance  = var.instance
  domain_id = each.key
  interface_thresholds = [
    for row in each.value : {
      node                  = row.node
      interface             = row.interface
      utilization_threshold = row.utilization_threshold_percent
    }
  ]

  depends_on = [
    crosswork_local_congestion_mitigation.local_congestion_mitigation,
    crosswork_network_devices.network_device,
  ]
}
