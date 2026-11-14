### SR-TE ODN TEMPLATES ###

locals {
  sr_te_odn_templates = {
    for template in try(local.crosswork.services.sr_te.odn_templates, []) : template.name => {
      name                                            = template.name
      color                                           = template.color
      head_end                                        = try(length(template.headends) == 0, true) ? null : [for headend in template.headends : { name = headend }]
      maximum_sid_depth                               = try(template.maximum_sid_depth, local.defaults.crosswork.services.sr_te.odn_templates.maximum_sid_depth, null)
      pce_group                                       = try(template.pce_group, local.defaults.crosswork.services.sr_te.odn_templates.pce_group, null)
      bandwidth                                       = try(template.bandwidth, local.defaults.crosswork.services.sr_te.odn_templates.bandwidth, null)
      source_address                                  = try(template.source_address, local.defaults.crosswork.services.sr_te.odn_templates.source_address, null)
      srv6_locator_name                               = try(template.srv6.locator.name, null)
      srv6_locator_behavior                           = try(template.srv6, null) == null ? null : try(template.srv6.locator.behavior, local.defaults.crosswork.services.sr_te.odn_templates.srv6.locator.behavior, null)
      srv6_locator_binding_sid_type                   = try(template.srv6, null) == null ? null : (try(template.srv6.locator.binding_sid_type, local.defaults.crosswork.services.sr_te.odn_templates.srv6.locator.binding_sid_type, null) == "dynamic" ? "srv6-dynamic" : null)
      dynamic_pce                                     = try(template.dynamic, null) == null ? null : (try(template.dynamic.pce, local.defaults.crosswork.services.sr_te.odn_templates.dynamic.pce, false) ? true : null)
      dynamic_flex_alg                                = try(template.dynamic, null) == null ? null : try(template.dynamic.flex_alg, local.defaults.crosswork.services.sr_te.odn_templates.dynamic.flex_alg, null)
      dynamic_metric_type                             = try(template.dynamic, null) == null ? null : try(template.dynamic.metric_type, local.defaults.crosswork.services.sr_te.odn_templates.dynamic.metric_type, null)
      dynamic_metric_margin_absolute                  = try(template.dynamic.metric_margin, null) == null ? null : try(template.dynamic.metric_margin.absolute, local.defaults.crosswork.services.sr_te.odn_templates.dynamic.metric_margin.absolute, null)
      dynamic_metric_margin_relative                  = try(template.dynamic.metric_margin, null) == null ? null : try(template.dynamic.metric_margin.relative, local.defaults.crosswork.services.sr_te.odn_templates.dynamic.metric_margin.relative, null)
      dynamic_affinity_rules                          = try(length(template.dynamic.affinity_rules) == 0, true) ? null : [for rule in template.dynamic.affinity_rules : { action = rule.action, color = toset(rule.colors) }]
      dynamic_segments_sid_algorithm                  = try(template.dynamic.segments.sid_algorithm, null)
      dynamic_disjoint_path_type                      = try(template.dynamic.disjoint_path.type, null)
      dynamic_disjoint_path_group_id                  = try(template.dynamic.disjoint_path.group_id, null)
      dynamic_disjoint_path_sub_id                    = try(template.dynamic.disjoint_path, null) == null ? null : try(template.dynamic.disjoint_path.sub_id, local.defaults.crosswork.services.sr_te.odn_templates.dynamic.disjoint_path.sub_id, null)
      performance_measurement_reverse_path_label      = try(template.performance_measurement, null) == null ? null : try(template.performance_measurement.reverse_path_label, local.defaults.crosswork.services.sr_te.odn_templates.performance_measurement.reverse_path_label, null)
      delay_measurement_profile                       = try(template.performance_measurement.delay_measurement, null) == null ? null : try(template.performance_measurement.delay_measurement.profile, local.defaults.crosswork.services.sr_te.odn_templates.performance_measurement.delay_measurement.profile, null)
      delay_measurement_logging_delay_exceeded        = try(template.performance_measurement.delay_measurement, null) == null ? null : (try(template.performance_measurement.delay_measurement.logging_delay_exceeded, local.defaults.crosswork.services.sr_te.odn_templates.performance_measurement.delay_measurement.logging_delay_exceeded, false) ? true : null)
      liveness_detection_profile                      = try(template.performance_measurement.liveness_detection, null) == null ? null : try(template.performance_measurement.liveness_detection.profile, local.defaults.crosswork.services.sr_te.odn_templates.performance_measurement.liveness_detection.profile, null)
      liveness_detection_backup                       = try(template.performance_measurement.liveness_detection, null) == null ? null : try(template.performance_measurement.liveness_detection.backup, local.defaults.crosswork.services.sr_te.odn_templates.performance_measurement.liveness_detection.backup, null)
      liveness_detection_invalidation_action          = try(template.performance_measurement.liveness_detection, null) == null ? null : try(template.performance_measurement.liveness_detection.invalidation_action, local.defaults.crosswork.services.sr_te.odn_templates.performance_measurement.liveness_detection.invalidation_action, null)
      liveness_detection_logging_session_state_change = try(template.performance_measurement.liveness_detection, null) == null ? null : (try(template.performance_measurement.liveness_detection.logging_session_state_change, local.defaults.crosswork.services.sr_te.odn_templates.performance_measurement.liveness_detection.logging_session_state_change, false) ? true : null)
    }
  }
}

resource "crosswork_srte_odn_templates" "odn_template" {
  for_each                                        = local.sr_te_odn_templates
  instance                                        = var.instance
  name                                            = each.value.name
  color                                           = each.value.color
  head_end                                        = each.value.head_end
  maximum_sid_depth                               = each.value.maximum_sid_depth
  pce_group                                       = each.value.pce_group
  bandwidth                                       = each.value.bandwidth
  source_address                                  = each.value.source_address
  srv6_locator_name                               = each.value.srv6_locator_name
  srv6_locator_behavior                           = each.value.srv6_locator_behavior
  srv6_locator_binding_sid_type                   = each.value.srv6_locator_binding_sid_type
  dynamic_pce                                     = each.value.dynamic_pce
  dynamic_flex_alg                                = each.value.dynamic_flex_alg
  dynamic_metric_type                             = each.value.dynamic_metric_type
  dynamic_metric_margin_absolute                  = each.value.dynamic_metric_margin_absolute
  dynamic_metric_margin_relative                  = each.value.dynamic_metric_margin_relative
  dynamic_affinity_rules                          = each.value.dynamic_affinity_rules
  dynamic_segments_sid_algorithm                  = each.value.dynamic_segments_sid_algorithm
  dynamic_disjoint_path_type                      = each.value.dynamic_disjoint_path_type
  dynamic_disjoint_path_group_id                  = each.value.dynamic_disjoint_path_group_id
  dynamic_disjoint_path_sub_id                    = each.value.dynamic_disjoint_path_sub_id
  performance_measurement_reverse_path_label      = each.value.performance_measurement_reverse_path_label
  delay_measurement_profile                       = each.value.delay_measurement_profile
  delay_measurement_logging_delay_exceeded        = each.value.delay_measurement_logging_delay_exceeded
  liveness_detection_profile                      = each.value.liveness_detection_profile
  liveness_detection_backup                       = each.value.liveness_detection_backup
  liveness_detection_invalidation_action          = each.value.liveness_detection_invalidation_action
  liveness_detection_logging_session_state_change = each.value.liveness_detection_logging_session_state_change

  depends_on = [
    crosswork_network_devices.network_device,
    crosswork_assign_devices_to_data_gateway.gateway,
    crosswork_golden_config_jobs.job
  ]
}

### SR-TE SID LISTS ###

locals {
  # The model lists the segments in path order and the controller numbers them: the index is the position, from 1.
  sr_te_sid_lists = {
    for sid_list in try(local.crosswork.services.sr_te.sid_lists, []) : sid_list.name => {
      name = sid_list.name
      sids = [for position, sid in sid_list.sids : { index = position + 1, label = try(sid.label, null), address = try(sid.address, null) }]
    }
  }
}

resource "crosswork_srte_sid_lists" "sid_list" {
  for_each = local.sr_te_sid_lists
  instance = var.instance
  name     = each.value.name
  sids     = each.value.sids
}

### SR-TE POLICIES ###

locals {
  sr_te_policies_defaults = try(local.defaults.crosswork.services.sr_te.policies, {})
  sr_te_policies = {
    for policy in try(local.crosswork.services.sr_te.policies, []) : policy.name => {
      name                                            = policy.name
      head_end                                        = policy.headend
      tail_end                                        = policy.tailend
      color                                           = policy.color
      binding_sid                                     = try(policy.binding_sid, local.sr_te_policies_defaults.binding_sid, null)
      bandwidth                                       = try(policy.bandwidth, local.sr_te_policies_defaults.bandwidth, null)
      source_address                                  = try(policy.source_address, local.sr_te_policies_defaults.source_address, null)
      srv6_locator_name                               = try(policy.srv6.locator.name, null)
      srv6_locator_behavior                           = try(policy.srv6, null) == null ? null : try(policy.srv6.locator.behavior, local.sr_te_policies_defaults.srv6.locator.behavior, null)
      srv6_locator_binding_sid_type                   = try(policy.srv6, null) == null ? null : (try(policy.srv6.locator.binding_sid_type, local.sr_te_policies_defaults.srv6.locator.binding_sid_type, null) == "dynamic" ? "srv6-dynamic" : null)
      performance_measurement_reverse_path_label      = try(policy.performance_measurement, null) == null ? null : try(policy.performance_measurement.reverse_path_label, local.sr_te_policies_defaults.performance_measurement.reverse_path_label, null)
      delay_measurement_profile                       = try(policy.performance_measurement.delay_measurement, null) == null ? null : try(policy.performance_measurement.delay_measurement.profile, local.sr_te_policies_defaults.performance_measurement.delay_measurement.profile, null)
      delay_measurement_logging_delay_exceeded        = try(policy.performance_measurement.delay_measurement, null) == null ? null : (try(policy.performance_measurement.delay_measurement.logging_delay_exceeded, local.sr_te_policies_defaults.performance_measurement.delay_measurement.logging_delay_exceeded, false) ? true : null)
      liveness_detection_profile                      = try(policy.performance_measurement.liveness_detection, null) == null ? null : try(policy.performance_measurement.liveness_detection.profile, local.sr_te_policies_defaults.performance_measurement.liveness_detection.profile, null)
      liveness_detection_backup                       = try(policy.performance_measurement.liveness_detection, null) == null ? null : try(policy.performance_measurement.liveness_detection.backup, local.sr_te_policies_defaults.performance_measurement.liveness_detection.backup, null)
      liveness_detection_invalidation_action          = try(policy.performance_measurement.liveness_detection, null) == null ? null : try(policy.performance_measurement.liveness_detection.invalidation_action, local.sr_te_policies_defaults.performance_measurement.liveness_detection.invalidation_action, null)
      liveness_detection_logging_session_state_change = try(policy.performance_measurement.liveness_detection, null) == null ? null : (try(policy.performance_measurement.liveness_detection.logging_session_state_change, local.sr_te_policies_defaults.performance_measurement.liveness_detection.logging_session_state_change, false) ? true : null)
      auto_route_metric_relative                      = try(policy.auto_route.metric.type == "relative" ? policy.auto_route.metric.value : null, null)
      auto_route_metric_constant                      = try(policy.auto_route.metric.type == "constant" ? policy.auto_route.metric.value : null, null)
      auto_route_include_prefixes                     = try(length(policy.auto_route.include_prefixes) == 0, true) ? null : [for prefix in policy.auto_route.include_prefixes : { prefix_address = prefix }]
      auto_route_force_sr_include                     = try(policy.auto_route, null) == null ? null : (try(policy.auto_route.force_sr_include, local.sr_te_policies_defaults.auto_route.force_sr_include, false) ? true : null)
      auto_route_forward_class                        = try(policy.auto_route, null) == null ? null : try(policy.auto_route.forward_class, local.sr_te_policies_defaults.auto_route.forward_class, null)
      paths = [
        for path in policy.paths : {
          preference                      = path.preference
          explicit_sid_lists              = try(path.explicit.sid_lists, null) == null ? null : [for sid_list in path.explicit.sid_lists : { name = sid_list.name, weight = try(sid_list.weight, null) }]
          explicit_affinity_rules         = try(length(path.explicit.affinity_rules) == 0, true) ? null : [for rule in path.explicit.affinity_rules : { action = rule.action, colors = toset(rule.colors) }]
          explicit_segments_sid_algorithm = try(path.explicit.segments.sid_algorithm, null)
          explicit_disjoint_path_type     = try(path.explicit.disjoint_path.type, null)
          explicit_disjoint_path_group_id = try(path.explicit.disjoint_path.group_id, null)
          explicit_disjoint_path_sub_id   = try(path.explicit.disjoint_path.sub_id, null)
          dynamic_pce                     = try(path.dynamic.pce, false) ? true : null
          dynamic_metric_type             = try(path.dynamic.metric_type, null)
          dynamic_metric_margin_absolute  = try(path.dynamic.metric_margin.absolute, null)
          dynamic_metric_margin_relative  = try(path.dynamic.metric_margin.relative, null)
          dynamic_sid_limit               = try(path.dynamic.sid_limit, null)
          dynamic_affinity_rules          = try(length(path.dynamic.affinity_rules) == 0, true) ? null : [for rule in path.dynamic.affinity_rules : { action = rule.action, colors = toset(rule.colors) }]
          dynamic_segments_sid_algorithm  = try(path.dynamic.segments.sid_algorithm, null)
          dynamic_disjoint_path_type      = try(path.dynamic.disjoint_path.type, null)
          dynamic_disjoint_path_group_id  = try(path.dynamic.disjoint_path.group_id, null)
          dynamic_disjoint_path_sub_id    = try(path.dynamic.disjoint_path.sub_id, null)
        }
      ]
    }
  }
}

resource "crosswork_srte_policies" "policy" {
  for_each                                        = local.sr_te_policies
  instance                                        = var.instance
  name                                            = each.value.name
  head_end                                        = each.value.head_end
  tail_end                                        = each.value.tail_end
  color                                           = each.value.color
  binding_sid                                     = each.value.binding_sid
  bandwidth                                       = each.value.bandwidth
  source_address                                  = each.value.source_address
  srv6_locator_name                               = each.value.srv6_locator_name
  srv6_locator_behavior                           = each.value.srv6_locator_behavior
  srv6_locator_binding_sid_type                   = each.value.srv6_locator_binding_sid_type
  performance_measurement_reverse_path_label      = each.value.performance_measurement_reverse_path_label
  delay_measurement_profile                       = each.value.delay_measurement_profile
  delay_measurement_logging_delay_exceeded        = each.value.delay_measurement_logging_delay_exceeded
  liveness_detection_profile                      = each.value.liveness_detection_profile
  liveness_detection_backup                       = each.value.liveness_detection_backup
  liveness_detection_invalidation_action          = each.value.liveness_detection_invalidation_action
  liveness_detection_logging_session_state_change = each.value.liveness_detection_logging_session_state_change
  auto_route_metric_relative                      = each.value.auto_route_metric_relative
  auto_route_metric_constant                      = each.value.auto_route_metric_constant
  auto_route_include_prefixes                     = each.value.auto_route_include_prefixes
  auto_route_force_sr_include                     = each.value.auto_route_force_sr_include
  auto_route_forward_class                        = each.value.auto_route_forward_class
  paths                                           = each.value.paths

  depends_on = [
    crosswork_network_devices.network_device,
    crosswork_assign_devices_to_data_gateway.gateway,
    crosswork_golden_config_jobs.job,
    crosswork_srte_sid_lists.sid_list
  ]
}
