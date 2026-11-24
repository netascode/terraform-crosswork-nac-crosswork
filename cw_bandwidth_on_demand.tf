### BANDWIDTH ON DEMAND ###

locals {
  bwod_objective = {
    "max-available-bandwidth" = "MAX_AVAIL_BW"
    "min-metric"              = "MIN_METRIC"
  }
  bwod_traffic = {
    "max-measured-requested" = "MAX_MEASURED_REQUESTED"
    "measured"               = "MEASURED"
  }
  bwod_violations = {
    "loose"  = "LOOSE"
    "strict" = "STRICT"
  }
  bwod_metric_reoptimization_time = split(":", try(
    local.crosswork.services.bandwidth_on_demand.basic.metric_reoptimization_time,
    local.defaults.crosswork.services.bandwidth_on_demand.basic.metric_reoptimization_time,
  ))
}

resource "crosswork_bandwidth_on_demand" "bandwidth_on_demand" {
  count                         = try(local.crosswork.services.bandwidth_on_demand, null) != null ? 1 : 0
  instance                      = var.instance
  enable                        = try(local.crosswork.services.bandwidth_on_demand.basic.enable, local.defaults.crosswork.services.bandwidth_on_demand.basic.enable, null)
  primary_objective             = lookup(local.bwod_objective, try(local.crosswork.services.bandwidth_on_demand.basic.primary_objective, local.defaults.crosswork.services.bandwidth_on_demand.basic.primary_objective, ""), null)
  link_utilization_threshold    = try(local.crosswork.services.bandwidth_on_demand.basic.link_utilization_threshold_percent, local.defaults.crosswork.services.bandwidth_on_demand.basic.link_utilization_threshold_percent, null)
  reoptimization_interval       = try(local.crosswork.services.bandwidth_on_demand.basic.reoptimization_interval_seconds, local.defaults.crosswork.services.bandwidth_on_demand.basic.reoptimization_interval_seconds, null)
  metric_reoptimization_hours   = tonumber(local.bwod_metric_reoptimization_time[0])
  metric_reoptimization_minutes = tonumber(local.bwod_metric_reoptimization_time[1])
  sr_policy_traffic             = lookup(local.bwod_traffic, try(local.crosswork.services.bandwidth_on_demand.advanced.sr_policy_traffic, local.defaults.crosswork.services.bandwidth_on_demand.advanced.sr_policy_traffic, ""), null)
  model_update_throttle         = try(local.crosswork.services.bandwidth_on_demand.advanced.update_throttle_seconds, local.defaults.crosswork.services.bandwidth_on_demand.advanced.update_throttle_seconds, null)
  optimizer_event_threshold     = try(local.crosswork.services.bandwidth_on_demand.advanced.optimizer_event_threshold_seconds, local.defaults.crosswork.services.bandwidth_on_demand.advanced.optimizer_event_threshold_seconds, null)
  optimizer_run_time_limit      = try(local.crosswork.services.bandwidth_on_demand.advanced.optimizer_run_time_limit_seconds, local.defaults.crosswork.services.bandwidth_on_demand.advanced.optimizer_run_time_limit_seconds, null)
  allowed_policy_violations     = lookup(local.bwod_violations, try(local.crosswork.services.bandwidth_on_demand.advanced.policy_violations, local.defaults.crosswork.services.bandwidth_on_demand.advanced.policy_violations, ""), null)
  prefer_strict_sids            = try(local.crosswork.services.bandwidth_on_demand.advanced.prefer_strict_sids, local.defaults.crosswork.services.bandwidth_on_demand.advanced.prefer_strict_sids, null)
  debug_optimizer               = try(local.crosswork.services.bandwidth_on_demand.advanced.debug_optimizer, local.defaults.crosswork.services.bandwidth_on_demand.advanced.debug_optimizer, null)
  debug_optimizer_max_files     = try(local.crosswork.services.bandwidth_on_demand.advanced.debug_optimizer_max_files, local.defaults.crosswork.services.bandwidth_on_demand.advanced.debug_optimizer_max_files, null)
}
