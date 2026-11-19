### L2VPN ID POOLS ###

locals {
  l2vpn_id_pools = try(local.crosswork.services.l2vpn.id_pools, null) == null ? {} : {
    id_pools = {
      evi_id_pool            = try(local.crosswork.services.l2vpn.id_pools.evi_id_pool, null)
      evi_source_target_pool = try(local.crosswork.services.l2vpn.id_pools.evi_source_target_pool, null)
      rt_pool                = try(local.crosswork.services.l2vpn.id_pools.rt_pool, null)
    }
  }
}

resource "crosswork_l2vpn_id_pools" "id_pools" {
  for_each               = { for key, pools in local.l2vpn_id_pools : key => pools if pools.evi_id_pool != null || pools.evi_source_target_pool != null || pools.rt_pool != null }
  instance               = var.instance
  evi_id_pool            = each.value.evi_id_pool
  evi_source_target_pool = each.value.evi_source_target_pool
  rt_pool                = each.value.rt_pool

  depends_on = [
    crosswork_resource_pools.resource_pool
  ]
}

### L2VPN TAG SETS ###

locals {
  l2vpn_tag_sets = {
    for set in try(local.crosswork.services.l2vpn.tag_sets, []) : set.name => {
      name      = set.name
      tag_value = try(set.value, null) == null ? null : [set.value]
      co_flag   = try(set.co_flag, null)
    }
  }
}

resource "crosswork_l2vpn_tag_sets" "tag_set" {
  for_each  = local.l2vpn_tag_sets
  instance  = var.instance
  name      = each.value.name
  tag_value = each.value.tag_value
  co_flag   = each.value.co_flag
}

### L2VPN RD SETS ###

locals {
  l2vpn_rd_sets = {
    for set in try(local.crosswork.services.l2vpn.rd_sets, []) : set.name => {
      name = set.name
      rd   = try(length(set.values) == 0, true) ? null : toset(set.values)
    }
  }
}

resource "crosswork_l2vpn_rd_sets" "rd_set" {
  for_each = local.l2vpn_rd_sets
  instance = var.instance
  name     = each.value.name
  rd       = each.value.rd
}

### L2VPN EVPN ROUTE TYPE SETS ###

locals {
  l2vpn_evpn_route_type_sets = {
    for set in try(local.crosswork.services.l2vpn.evpn_route_type_sets, []) : set.name => {
      name            = set.name
      evpn_route_type = try(length(set.values) == 0, true) ? null : toset(set.values)
    }
  }
}

resource "crosswork_l2vpn_evpn_route_type_sets" "evpn_route_type_set" {
  for_each        = local.l2vpn_evpn_route_type_sets
  instance        = var.instance
  name            = each.value.name
  evpn_route_type = each.value.evpn_route_type
}

### L2VPN ETAG SETS ###

locals {
  l2vpn_etag_sets = {
    for set in try(local.crosswork.services.l2vpn.etag_sets, []) : set.name => {
      name = set.name
      etag = try(length(set.values) == 0, true) ? null : toset(set.values)
    }
  }
}

resource "crosswork_l2vpn_etag_sets" "etag_set" {
  for_each = local.l2vpn_etag_sets
  instance = var.instance
  name     = each.value.name
  etag     = each.value.etag
}

### L2VPN ROUTING POLICIES ###

locals {
  l2vpn_routing_policies = {
    for policy in try(local.crosswork.services.l2vpn.routing_policies, []) : policy.name => {
      name = policy.name
      statements = try(length(policy.statements) == 0, true) ? null : [for statement in policy.statements : {
        name                      = statement.name
        match_rd_set              = try(statement.conditions.match_rd_set, null)
        match_evpn_route_type_set = try(statement.conditions.match_evpn_route_type_set, null)
        match_etag_set            = try(statement.conditions.match_etag_set, null)
        set_ext_community         = statement.actions.set_ext_community_tag_set
      }]
    }
  }
}

resource "crosswork_l2vpn_route_policies" "routing_policy" {
  for_each   = local.l2vpn_routing_policies
  instance   = var.instance
  name       = each.value.name
  statements = each.value.statements

  depends_on = [
    crosswork_l2vpn_tag_sets.tag_set,
    crosswork_l2vpn_rd_sets.rd_set,
    crosswork_l2vpn_evpn_route_type_sets.evpn_route_type_set,
    crosswork_l2vpn_etag_sets.etag_set
  ]
}

### L2VPN QOS PROFILES ###

locals {
  l2vpn_qos_profiles = toset(try(local.crosswork.services.l2vpn.qos_profiles, []))
}

resource "crosswork_l2vpn_qos_profile_ids" "qos_profile" {
  for_each = local.l2vpn_qos_profiles
  instance = var.instance
  name     = each.value
}

### L2VPN Y1731 PROFILES ###

locals {
  l2vpn_y1731_profiles = {
    for profile in try(local.crosswork.services.l2vpn.y1731_profiles, []) : profile.name => {
      name                       = profile.name
      type                       = profile.type
      schedule_interval          = try(profile.schedule.interval, null)
      schedule_duration          = try(profile.schedule.duration, null) == null ? null : tostring(profile.schedule.duration)
      probe_type                 = try(profile.probe.type, null)
      probe_message_count        = try(profile.probe.message_count, null)
      probe_message_period       = try(profile.probe.message_period, null)
      probe_measurement_interval = try(profile.probe.measurement_interval, null) == null ? null : tostring(profile.probe.measurement_interval)
      probe_frame_size           = try(profile.probe.frame_size, null)
      probe_priority             = try(profile.probe.priority, null)
      delay_statistics           = try(length(profile.delay_statistics) == 0, true) ? null : [for statistic in profile.delay_statistics : { type = statistic }]
      loss_statistics            = try(length(profile.loss_statistics) == 0, true) ? null : [for statistic in profile.loss_statistics : { type = statistic }]
      bucket_size                = try(profile.bucket_size, null)
      bucket_archive             = try(profile.bucket_archive, null)
    }
  }
}

resource "crosswork_l2vpn_y1731_profiles" "y1731_profile" {
  for_each                   = local.l2vpn_y1731_profiles
  instance                   = var.instance
  name                       = each.value.name
  type                       = each.value.type
  schedule_interval          = each.value.schedule_interval
  schedule_duration          = each.value.schedule_duration
  probe_type                 = each.value.probe_type
  probe_message_count        = each.value.probe_message_count
  probe_message_period       = each.value.probe_message_period
  probe_measurement_interval = each.value.probe_measurement_interval
  probe_frame_size           = each.value.probe_frame_size
  probe_priority             = each.value.probe_priority
  delay_statistics           = each.value.delay_statistics
  loss_statistics            = each.value.loss_statistics
  bucket_size                = each.value.bucket_size
  bucket_archive             = each.value.bucket_archive
}

### L2VPN VPN SERVICES ###

locals {
  l2vpn_service_defaults  = try(local.defaults.crosswork.services.l2vpn.vpn_services, {})
  l2vpn_assurance_default = try(local.l2vpn_service_defaults.service_assurance, {})
  l2vpn_access_defaults   = try(local.l2vpn_service_defaults.nodes.accesses, {})
  l2vpn_oam_defaults      = try(local.l2vpn_access_defaults.oam, {})

  l2vpn_vpn_services = {
    for service in try(local.crosswork.services.l2vpn.vpn_services, []) : service.name => {
      vpn_id                             = service.name
      vpn_type                           = "ietf-vpn-common:${try(service.type, local.l2vpn_service_defaults.type, "vpws-evpn")}"
      evi_id                             = try(service.evi.id, null) == "auto" ? null : try(service.evi.id, null)
      auto_evi_id                        = try(service.evi.id, null) == "auto" ? true : null
      evi_source                         = try(service.evi.source, null) == "auto" ? null : try(service.evi.source, null)
      auto_evi_source                    = try(service.evi.source, null) == "auto" ? true : null
      evi_target                         = try(service.evi.target, null) == "auto" ? null : try(service.evi.target, null)
      auto_evi_target                    = try(service.evi.target, null) == "auto" ? true : null
      service_assurance_profile_name     = try(service.service_assurance.profile, null) == null ? null : "${service.service_assurance.profile}${try(service.service_assurance.profile_type, local.l2vpn_assurance_default.profile_type, "system") == "system" ? " system" : ""}"
      service_assurance_rule_name        = try(service.service_assurance.rule, null) == null ? null : "${service.service_assurance.rule}${try(service.service_assurance.rule_type, local.l2vpn_assurance_default.rule_type, "system") == "system" ? " system" : ""}"
      service_assurance_monitoring_state = try(service.service_assurance, null) == null ? null : try(service.service_assurance.monitoring_state, local.l2vpn_assurance_default.monitoring_state, null)
      service_assurance_preservation     = try(service.service_assurance, null) == null ? null : try(service.service_assurance.preservation, local.l2vpn_assurance_default.preservation, null)
      vpn_nodes = [for node in service.nodes : {
        vpn_node_id                            = node.device
        multi_home_ethernet_segment_identifier = try(node.multi_home.ethernet_segment_identifier, null)
        sr_policy                              = try(node.te_mapping.sr_policy.name, null)
        sr_policy_fallback                     = try(node.te_mapping.sr_policy.name, null) == null ? null : "disable"
        odn_route_policies                     = try(node.te_mapping.odn.route_policy, null) == null ? null : [node.te_mapping.odn.route_policy]
        vpn_network_accesses = [for access in node.accesses : {
          id                      = tostring(access.id)
          description             = try(access.description, local.l2vpn_access_defaults.description, null)
          interface_id            = access.interface
          encapsulation_type      = try(access.vlan, local.l2vpn_access_defaults.vlan, null) == null ? "ietf-vpn-common:untagged-int" : "ietf-vpn-common:dot1q"
          cvlan_id                = try(access.vlan, local.l2vpn_access_defaults.vlan, null)
          tag_operation_pop       = try(access.tag_operations.pop, null) == null ? null : tostring(access.tag_operations.pop)
          tag_operation_push      = try(access.tag_operations.push, null) == null ? null : true
          tag_operation_translate = try(access.tag_operations.translate, null) == null ? null : "1-to-1"
          tag_operation_tag       = try(access.tag_operations.push, access.tag_operations.translate, null)
          mtu                     = try(access.mtu, local.l2vpn_access_defaults.mtu, null)
          qos_profiles            = try(length(access.qos_profiles) == 0, true) ? null : [for entry in access.qos_profiles : { profile = entry.name, direction = "ietf-vpn-common:${local.l3vpn_qos_directions[entry.direction]}" }]
          oam_md_name             = try(access.oam.md_name, null)
          oam_md_level            = try(access.oam.md_level, null)
          oam_maid                = try(access.oam.maid, null) == null ? null : tostring(access.oam.maid)
          oam_mep_id              = try(access.oam.mep_id, null)
          oam_message_period      = try(access.oam, null) == null ? null : try(access.oam.message_period, local.l2vpn_oam_defaults.message_period, null)
          oam_id_type             = try(access.oam, null) == null ? null : try(access.oam.id_type, local.l2vpn_oam_defaults.id_type, null)
          oam_y1731_profiles = try(length(access.oam.profiles) == 0, true) ? null : [for profile in access.oam.profiles : {
            name              = profile.name
            schedule_interval = try(profile.interval, null)
            schedule_duration = try(profile.duration, null) == null ? null : tostring(profile.duration)
          }]
        }]
      }]
    }
  }
}

resource "crosswork_l2vpn_vpn_services" "vpn_service" {
  for_each                           = local.l2vpn_vpn_services
  instance                           = var.instance
  vpn_id                             = each.value.vpn_id
  vpn_type                           = each.value.vpn_type
  evi_id                             = each.value.evi_id
  auto_evi_id                        = each.value.auto_evi_id
  evi_source                         = each.value.evi_source
  auto_evi_source                    = each.value.auto_evi_source
  evi_target                         = each.value.evi_target
  auto_evi_target                    = each.value.auto_evi_target
  service_assurance_profile_name     = each.value.service_assurance_profile_name
  service_assurance_rule_name        = each.value.service_assurance_rule_name
  service_assurance_monitoring_state = each.value.service_assurance_monitoring_state
  service_assurance_preservation     = each.value.service_assurance_preservation
  vpn_nodes                          = each.value.vpn_nodes

  depends_on = [
    crosswork_network_devices.network_device,
    crosswork_assign_devices_to_data_gateway.gateway,
    crosswork_golden_config_jobs.job_9,
    crosswork_l2vpn_y1731_profiles.y1731_profile,
    crosswork_l2vpn_route_policies.routing_policy,
    crosswork_l2vpn_qos_profile_ids.qos_profile,
    crosswork_l2vpn_id_pools.id_pools,
    crosswork_srte_policies.policy,
    crosswork_srte_odn_templates.odn_template
  ]
}
