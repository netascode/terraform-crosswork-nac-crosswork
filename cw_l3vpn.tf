### L3VPN SOURCE PREFIX SETS ###

locals {
  l3vpn_source_prefix_sets = {
    for set in try(local.crosswork.services.l3vpn.prefix_sets, []) : set.name => {
      name        = set.name
      mode        = set.mode
      prefix_list = try(length(set.prefixes) == 0, true) ? null : [for prefix in set.prefixes : { ip_prefix = prefix }]
    } if set.direction == "source"
  }
}

resource "crosswork_l3vpn_source_prefix_sets" "source_prefix_set" {
  for_each    = local.l3vpn_source_prefix_sets
  instance    = var.instance
  name        = each.value.name
  mode        = each.value.mode
  prefix_list = each.value.prefix_list
}

### L3VPN DESTINATION PREFIX SETS ###

locals {
  l3vpn_destination_prefix_sets = {
    for set in try(local.crosswork.services.l3vpn.prefix_sets, []) : set.name => {
      name        = set.name
      mode        = set.mode
      prefix_list = try(length(set.prefixes) == 0, true) ? null : [for prefix in set.prefixes : { ip_prefix = prefix }]
    } if set.direction == "destination"
  }
}

resource "crosswork_l3vpn_destination_prefix_sets" "destination_prefix_set" {
  for_each    = local.l3vpn_destination_prefix_sets
  instance    = var.instance
  name        = each.value.name
  mode        = each.value.mode
  prefix_list = each.value.prefix_list
}

### L3VPN TAG SETS ###

locals {
  l3vpn_tag_sets = {
    for set in try(local.crosswork.services.l3vpn.tag_sets, []) : set.name => {
      name      = set.name
      tag_value = try(set.value, null) == null ? null : [set.value]
    }
  }
}

resource "crosswork_l3vpn_tag_sets" "tag_set" {
  for_each  = local.l3vpn_tag_sets
  instance  = var.instance
  name      = each.value.name
  tag_value = each.value.tag_value
}

### L3VPN ROUTING POLICIES ###

locals {
  l3vpn_routing_policies = {
    for policy in try(local.crosswork.services.l3vpn.routing_policies, []) : policy.name => {
      name = policy.name
      statements = try(length(policy.statements) == 0, true) ? null : [for statement in policy.statements : {
        name                    = statement.name
        match_source_prefix_set = try(statement.conditions.match_source_prefix_set, null)
        match_dest_prefix_set   = try(statement.conditions.match_destination_prefix_set, null)
        policy_result           = "accept-route"
        set_ext_community       = statement.actions.set_ext_community_tag_set
      }]
    }
  }
}

resource "crosswork_l3vpn_route_policies" "routing_policy" {
  for_each   = local.l3vpn_routing_policies
  instance   = var.instance
  name       = each.value.name
  statements = each.value.statements

  depends_on = [
    crosswork_l3vpn_source_prefix_sets.source_prefix_set,
    crosswork_l3vpn_destination_prefix_sets.destination_prefix_set,
    crosswork_l3vpn_tag_sets.tag_set
  ]
}

### L3VPN QOS PROFILES ###

locals {
  l3vpn_qos_profiles = toset(try(local.crosswork.services.l3vpn.qos_profiles, []))
}

resource "crosswork_l3vpn_qos_profile_ids" "qos_profile" {
  for_each = local.l3vpn_qos_profiles
  instance = var.instance
  name     = each.value
}

### L3VPN VPN SERVICES ###

locals {
  # defaults of the optional leaves, one alias for each level of the model
  l3vpn_service_defaults  = try(local.defaults.crosswork.services.l3vpn.vpn_services, {})
  l3vpn_assurance_default = try(local.l3vpn_service_defaults.service_assurance, {})
  l3vpn_profile_defaults  = try(local.l3vpn_service_defaults.profiles, {})
  l3vpn_node_defaults     = try(local.l3vpn_service_defaults.nodes, {})
  l3vpn_access_defaults   = try(local.l3vpn_node_defaults.accesses, {})
  l3vpn_bgp_defaults      = try(local.l3vpn_access_defaults.routing_protocols.bgp, {})

  # a QoS direction is named by the device: wan-to-site is the input of the interface, site-to-wan the output
  l3vpn_qos_directions = { input = "wan-to-site", output = "site-to-wan", both = "both" }

  # NSO takes the router distinguisher and the route targets as the model writes them. A route target gets its position
  # in the list as its number, and a redistribution is always enabled (an entry without enable is not pushed).
  l3vpn_vpn_services = {
    for service in try(local.crosswork.services.l3vpn.vpn_services, []) : service.name => {
      vpn_id                             = service.name
      vpn_service_topology               = try(service.topology, local.l3vpn_service_defaults.topology, null) == null ? null : "ietf-vpn-common:${try(service.topology, local.l3vpn_service_defaults.topology)}"
      auto_hub_rt                        = try(service.auto_hub_rt, local.l3vpn_service_defaults.auto_hub_rt, false) ? true : null
      auto_spoke_rt                      = try(service.auto_spoke_rt, local.l3vpn_service_defaults.auto_spoke_rt, false) ? true : null
      service_assurance_profile_name     = try(service.service_assurance.profile, null) == null ? null : "${service.service_assurance.profile}${try(service.service_assurance.profile_type, local.l3vpn_assurance_default.profile_type, "system") == "system" ? " system" : ""}"
      service_assurance_rule_name        = try(service.service_assurance.rule, null) == null ? null : "${service.service_assurance.rule}${try(service.service_assurance.rule_type, local.l3vpn_assurance_default.rule_type, "system") == "system" ? " system" : ""}"
      service_assurance_monitoring_state = try(service.service_assurance, null) == null ? null : try(service.service_assurance.monitoring_state, local.l3vpn_assurance_default.monitoring_state, null)
      service_assurance_preservation     = try(service.service_assurance, null) == null ? null : try(service.service_assurance.preservation, local.l3vpn_assurance_default.preservation, null)
      vpn_instance_profiles = [for profile in service.profiles : {
        profile_id = profile.name
        role       = try(profile.role, local.l3vpn_profile_defaults.role, null) == null ? null : "ietf-vpn-common:${try(profile.role, local.l3vpn_profile_defaults.role)}-role"
        rd         = try(profile.rd, local.l3vpn_profile_defaults.rd, null)
        local_as   = try(profile.local_as, local.l3vpn_profile_defaults.local_as, null)
        address_families = [for family in profile.address_families : {
          address_family = "ietf-vpn-common:${family.family}"
          vpn_targets    = try(length(family.route_targets) == 0, true) ? null : [for index, target in family.route_targets : { id = index + 1, route_target_type = target.type, route_targets = [{ route_target = target.value }] }]
          import_policy  = try(family.import_policy, null)
          export_policy  = try(family.export_policy, null)
        }]
      }]
      vpn_nodes = try(length(service.nodes) == 0, true) ? null : [for node in service.nodes : {
        vpn_node_id = node.device
        local_as    = try(node.local_as, local.l3vpn_node_defaults.local_as, null)
        active_vpn_instance_profiles = [{
          profile_id = node.profile
          rd         = try(node.rd, local.l3vpn_node_defaults.rd, null)
          address_families = try(length(node.address_families) == 0, true) ? null : [for family in node.address_families : {
            address_family = "ietf-vpn-common:${family.family}"
            vpn_targets    = try(length(family.route_targets) == 0, true) ? null : [for index, target in family.route_targets : { id = index + 1, route_target_type = target.type, route_targets = [{ route_target = target.value }] }]
            import_policy  = try(family.import_policy, null)
            export_policy  = try(family.export_policy, null)
          }]
        }]
        vpn_network_accesses = [for access in node.accesses : {
          id                 = tostring(access.id)
          interface_id       = access.interface
          encapsulation_type = try(access.vlan, local.l3vpn_access_defaults.vlan, null) == null ? null : "ietf-vpn-common:dot1q"
          cvlan_id           = try(access.vlan, local.l3vpn_access_defaults.vlan, null)
          ipv4_address       = try(access.ipv4.address, null)
          ipv4_prefix_length = try(access.ipv4.prefix_length, null)
          ipv6_address       = try(access.ipv6.address, null)
          ipv6_prefix_length = try(access.ipv6.prefix_length, null)
          mtu                = try(access.mtu, local.l3vpn_access_defaults.mtu, null)
          qos_profiles       = try(length(access.qos_profiles) == 0, true) ? null : [for entry in access.qos_profiles : { profile = entry.name, direction = "ietf-vpn-common:${local.l3vpn_qos_directions[entry.direction]}" }]
          routing_protocols = try(length(access.routing_protocols) == 0, true) ? null : [for protocol in access.routing_protocols : {
            id                          = protocol.id
            type                        = "ietf-vpn-common:${protocol.type}"
            bgp_peer_as                 = try(protocol.bgp.peer_as, null)
            bgp_address_family          = try(protocol.bgp, null) == null ? null : try(protocol.bgp.address_family, local.l3vpn_bgp_defaults.address_family, null)
            bgp_neighbors               = try(length(protocol.bgp.neighbors) == 0, true) ? null : toset(protocol.bgp.neighbors)
            bgp_multihop                = try(protocol.bgp, null) == null ? null : try(protocol.bgp.multihop, local.l3vpn_bgp_defaults.multihop, null)
            bgp_redistribute_connected  = try(length(protocol.bgp.redistribute_connected) == 0, true) ? null : [for entry in protocol.bgp.redistribute_connected : { address_family = "ietf-vpn-common:${entry.address_family}", enable = true, metric = try(entry.metric, null) }]
            bgp_update_source_if_type   = try(protocol.bgp.update_source.if_type, null)
            bgp_update_source_if_id     = try(protocol.bgp.update_source.if_id, null)
            bgp_update_source_sub_if_id = try(protocol.bgp.update_source.sub_if_id, null)
          }]
        }]
      }]
    }
  }
}

resource "crosswork_l3vpn_vpn_services" "vpn_service" {
  for_each                           = local.l3vpn_vpn_services
  instance                           = var.instance
  vpn_id                             = each.value.vpn_id
  vpn_service_topology               = each.value.vpn_service_topology
  auto_hub_rt                        = each.value.auto_hub_rt
  auto_spoke_rt                      = each.value.auto_spoke_rt
  service_assurance_profile_name     = each.value.service_assurance_profile_name
  service_assurance_rule_name        = each.value.service_assurance_rule_name
  service_assurance_monitoring_state = each.value.service_assurance_monitoring_state
  service_assurance_preservation     = each.value.service_assurance_preservation
  vpn_instance_profiles              = each.value.vpn_instance_profiles
  vpn_nodes                          = each.value.vpn_nodes

  depends_on = [
    crosswork_network_devices.network_device,
    crosswork_assign_devices_to_data_gateway.gateway,
    crosswork_l3vpn_route_policies.routing_policy,
    crosswork_l3vpn_qos_profile_ids.qos_profile,
    crosswork_resource_pools.resource_pool,
    crosswork_golden_config_jobs.job_9,
    crosswork_srte_policies.policy,
    crosswork_srte_odn_templates.odn_template
  ]
}
