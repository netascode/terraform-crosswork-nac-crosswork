<!-- BEGIN_TF_DOCS -->
# Terraform Network-as-Code Cisco Crosswork Module

A Terraform module to configure Cisco Crosswork Network Controller.

## Usage

This module supports an inventory driven approach, where a complete Crosswork configuration or parts of it are either modeled in one or more YAML files or natively using Terraform variables.

## Examples

Configuring roles, users and credential profiles using YAML:

#### `administration.yaml`

```yaml
---
crosswork:
  administration:
    roles:
      - name: cwtest-operator
        api_permissions:
          - category: device-monitoring
            access: read
          - task: alarms-events
            access: read
          - task: alarm-notification-policies
            access: read-write
        task_permissions:
          - view-audit-logs
    users:
      - username: cwtest-user
        password: CwtestPass123!
        password_version: 1
        first_name: Test
        last_name: User
        role: cwtest-operator
        device_access_groups:
          - ALL-ACCESS
        locked: false
  providers:
    profiles:
      - name: nso
        family: NSO
        credential_profile: nso-profile
        connectivity:
          - protocol: SSH
            ip_address: 10.10.10.2
            port: 22
          - protocol: NETCONF
            ip_address: 10.10.10.2
            port: 2022
          - protocol: HTTPS
            ip_address: 10.10.10.2
            port: 8888
        models:
          - prefix: cisco-ios-xr
            version: 7.8.2
```

#### `device_management.yaml`

```yaml
---
crosswork:
  device_management:
    credential_profiles:
      - name: device-profile
        credentials:
          - type: SSH
            user_name: cwtest
            password: CwtestPass123!
            password_version: 1
          - type: SNMPv2
            read_community: cwtest-read
            read_community_version: 1
      - name: nso-profile
        credentials:
          - type: SSH
            user_name: cwtest
            password: CwtestPass123!
            password_version: 1
          - type: NETCONF
            user_name: cwtest
            password: CwtestPass123!
            password_version: 1
          - type: HTTPS
            user_name: cwtest
            password: CwtestPass123!
            password_version: 1
    network_devices:
      - name: router-1
        connectivity:
          credential_profile: device-profile
          capabilities:
            - SNMP
          protocols:
            - protocol: SSH
              ip_address: 10.10.10.1
              prefix_length: 24
            - protocol: SNMP
              ip_address: 10.10.10.1
              prefix_length: 32
              timeout: 120
        providers:
          family: NSO
          name: nso
        location:
          latitude: 37.33
          longitude: -121.89
```

#### `main.tf`

```hcl
module "crosswork" {
  source  = "netascode/nac-crosswork/crosswork"
  version = "0.1.0"

  yaml_files = ["administration.yaml", "device_management.yaml"]
}
```

## Using the provider before it is in the Terraform Registry

The `CiscoDevNet/crosswork` provider is not published to the Terraform Registry yet. Until it is, build it and install it from a local filesystem mirror. A development override is not enough: `terraform init` fails for a provider that the Registry does not have.

1. Build the provider (Go 1.26 or later):

```bash
git clone https://github.com/netascode/terraform-provider-crosswork.git
cd terraform-provider-crosswork
go build -o terraform-provider-crosswork .
```

2. Install it in a mirror folder. Use your own operating system and architecture instead of `linux_amd64`, and a version that `versions.tf` accepts:

```bash
DIR=$HOME/terraform-mirror/registry.terraform.io/ciscodevnet/crosswork/0.1.0/linux_amd64
mkdir -p $DIR
cp terraform-provider-crosswork $DIR/terraform-provider-crosswork_v0.1.0
```

3. Take this provider from the mirror and all others from the Registry. This writes `~/.terraformrc`; merge it into your file if you already have one:

```bash
cat > ~/.terraformrc << EOF
provider_installation {
  filesystem_mirror {
    path    = "$HOME/terraform-mirror"
    include = ["CiscoDevNet/crosswork"]
  }
  direct {
    exclude = ["CiscoDevNet/crosswork"]
  }
}
EOF
```

4. Clone this module next to the provider and replace the example `main.tf` with one that uses your clone instead of the Registry. A `version` argument is only valid for a Registry source, so it is left out. This changes a file of the clone, so do not commit it:

```bash
cd ..
git clone https://github.com/netascode/terraform-crosswork-nac-crosswork.git
cd terraform-crosswork-nac-crosswork
cat > examples/basic/main.tf << 'EOF'
module "crosswork" {
  source = "../.."

  yaml_files = ["administration.yaml", "device_management.yaml"]
}
EOF
```

5. Set `CW_URL`, `CW_USERNAME` and `CW_PASSWORD`, then run Terraform in the example folder:

```bash
cd examples/basic
terraform init
terraform plan
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_crosswork"></a> [crosswork](#requirement\_crosswork) | ~> 0.1.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.3.0 |
| <a name="requirement_utils"></a> [utils](#requirement\_utils) | >= 2.0.0 |
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_golden_configuration_directories"></a> [golden\_configuration\_directories](#input\_golden\_configuration\_directories) | List of paths to directories with the Golden Configuration template files (`.j2`); the files in the directory and in its subfolders can be used by a template. | `list(string)` | `[]` | no |
| <a name="input_golden_configuration_files"></a> [golden\_configuration\_files](#input\_golden\_configuration\_files) | List of paths to Golden Configuration template files (`.j2`) that a template can use. | `list(string)` | `[]` | no |
| <a name="input_instance"></a> [instance](#input\_instance) | Name of the provider instance (controller) the resources are created on. Leave it unset to use the default instance. | `string` | `null` | no |
| <a name="input_model"></a> [model](#input\_model) | As an alternative to YAML files, a native Terraform data structure can be provided as well. | `map(any)` | `{}` | no |
| <a name="input_write_default_values_file"></a> [write\_default\_values\_file](#input\_write\_default\_values\_file) | Write all default values to a YAML file. Value is a path pointing to the file to be created. | `string` | `""` | no |
| <a name="input_yaml_directories"></a> [yaml\_directories](#input\_yaml\_directories) | List of paths to YAML directories. | `list(string)` | `[]` | no |
| <a name="input_yaml_files"></a> [yaml\_files](#input\_yaml\_files) | List of paths to YAML files. | `list(string)` | `[]` | no |
## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_default_values"></a> [default\_values](#output\_default\_values) | All default values. |
| <a name="output_model"></a> [model](#output\_model) | Full model with the write-only secrets omitted. Secrets without a `_version` are still included, so the value is marked sensitive. |
## Resources

| Name | Type |
| ---- | ---- |
| [crosswork_aaa_ldap_servers.ldap](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/aaa_ldap_servers) | resource |
| [crosswork_aaa_password_policy.password](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/aaa_password_policy) | resource |
| [crosswork_aaa_radius_servers.radius](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/aaa_radius_servers) | resource |
| [crosswork_aaa_session_settings.session](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/aaa_session_settings) | resource |
| [crosswork_aaa_sso_services.sso](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/aaa_sso_services) | resource |
| [crosswork_aaa_tacacs_servers.tacacs](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/aaa_tacacs_servers) | resource |
| [crosswork_alarm_settings.alarm_settings](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/alarm_settings) | resource |
| [crosswork_assign_devices_to_access_group.assignment](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/assign_devices_to_access_group) | resource |
| [crosswork_assign_devices_to_data_gateway.gateway](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/assign_devices_to_data_gateway) | resource |
| [crosswork_assign_devices_to_device_group.assignment](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/assign_devices_to_device_group) | resource |
| [crosswork_assign_ports_to_port_group.assignment](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/assign_ports_to_port_group) | resource |
| [crosswork_backup_destination.backup_destination](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/backup_destination) | resource |
| [crosswork_bandwidth_on_demand.bandwidth_on_demand](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/bandwidth_on_demand) | resource |
| [crosswork_collection_jobs.collection_job](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/collection_jobs) | resource |
| [crosswork_collection_jobs_cadence.cadence](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/collection_jobs_cadence) | resource |
| [crosswork_credential_profiles.credential_profile](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/credential_profiles) | resource |
| [crosswork_data_gateway_destinations.destination](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/data_gateway_destinations) | resource |
| [crosswork_data_gateway_global_parameters.global_parameters](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/data_gateway_global_parameters) | resource |
| [crosswork_data_gateway_pools.pool](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/data_gateway_pools) | resource |
| [crosswork_data_gateway_resource_configuration.resource_configurations](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/data_gateway_resource_configuration) | resource |
| [crosswork_data_retention_device_performance.device_performance](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/data_retention_device_performance) | resource |
| [crosswork_data_retention_network_performance.network_performance](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/data_retention_network_performance) | resource |
| [crosswork_demand_matrix_domain.domain](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/demand_matrix_domain) | resource |
| [crosswork_demand_matrix_global_configuration.global_configuration](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/demand_matrix_global_configuration) | resource |
| [crosswork_device_access_groups.level_1](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_10](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_2](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_3](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_4](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_5](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_6](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_7](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_8](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_access_groups.level_9](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_access_groups) | resource |
| [crosswork_device_groups.level_1](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_10](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_2](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_3](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_4](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_5](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_6](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_7](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_8](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_groups.level_9](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_groups) | resource |
| [crosswork_device_notification_policies.device](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/device_notification_policies) | resource |
| [crosswork_file_servers.file_servers](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/file_servers) | resource |
| [crosswork_gnmi_settings.gnmi](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/gnmi_settings) | resource |
| [crosswork_golden_config_global_variables.global_variable](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_global_variables) | resource |
| [crosswork_golden_config_jobs.job_0](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_1](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_2](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_3](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_4](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_5](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_6](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_7](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_8](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_jobs.job_9](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_jobs) | resource |
| [crosswork_golden_config_templates.template](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/golden_config_templates) | resource |
| [crosswork_health_settings.health_settings](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/health_settings) | resource |
| [crosswork_l2vpn_etag_sets.etag_set](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_etag_sets) | resource |
| [crosswork_l2vpn_evpn_route_type_sets.evpn_route_type_set](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_evpn_route_type_sets) | resource |
| [crosswork_l2vpn_id_pools.id_pools](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_id_pools) | resource |
| [crosswork_l2vpn_qos_profile_ids.qos_profile](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_qos_profile_ids) | resource |
| [crosswork_l2vpn_rd_sets.rd_set](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_rd_sets) | resource |
| [crosswork_l2vpn_route_policies.routing_policy](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_route_policies) | resource |
| [crosswork_l2vpn_tag_sets.tag_set](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_tag_sets) | resource |
| [crosswork_l2vpn_vpn_services.vpn_service](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_vpn_services) | resource |
| [crosswork_l2vpn_y1731_profiles.y1731_profile](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l2vpn_y1731_profiles) | resource |
| [crosswork_l3vpn_destination_prefix_sets.destination_prefix_set](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l3vpn_destination_prefix_sets) | resource |
| [crosswork_l3vpn_qos_profile_ids.qos_profile](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l3vpn_qos_profile_ids) | resource |
| [crosswork_l3vpn_route_policies.routing_policy](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l3vpn_route_policies) | resource |
| [crosswork_l3vpn_source_prefix_sets.source_prefix_set](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l3vpn_source_prefix_sets) | resource |
| [crosswork_l3vpn_tag_sets.tag_set](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l3vpn_tag_sets) | resource |
| [crosswork_l3vpn_vpn_services.vpn_service](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/l3vpn_vpn_services) | resource |
| [crosswork_local_congestion_mitigation.local_congestion_mitigation](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/local_congestion_mitigation) | resource |
| [crosswork_local_congestion_mitigation_interface_thresholds.local_congestion_mitigation_interface_thresholds](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/local_congestion_mitigation_interface_thresholds) | resource |
| [crosswork_lock_users.lock_user](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/lock_users) | resource |
| [crosswork_login_banner.login_banner](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/login_banner) | resource |
| [crosswork_metric_thresholds.metric_thresholds](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/metric_thresholds) | resource |
| [crosswork_network_devices.network_device](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/network_devices) | resource |
| [crosswork_performance_policies.policy](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/performance_policies) | resource |
| [crosswork_port_groups.port_group](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/port_groups) | resource |
| [crosswork_port_groups_rules.rule](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/port_groups_rules) | resource |
| [crosswork_provider_nso_policies.nso_policy](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/provider_nso_policies) | resource |
| [crosswork_provider_profiles.provider_profile](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/provider_profiles) | resource |
| [crosswork_resource_pools.resource_pool](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/resource_pools) | resource |
| [crosswork_roles.role](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/roles) | resource |
| [crosswork_smart_licensing_transport.smart_licensing](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/smart_licensing_transport) | resource |
| [crosswork_srte_odn_templates.odn_template](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/srte_odn_templates) | resource |
| [crosswork_srte_policies.policy](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/srte_policies) | resource |
| [crosswork_srte_sid_lists.sid_list](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/srte_sid_lists) | resource |
| [crosswork_static_route.static_route](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/static_route) | resource |
| [crosswork_suppression_policies.suppression](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/suppression_policies) | resource |
| [crosswork_survey_settings.survey](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/survey_settings) | resource |
| [crosswork_syslog_destination.syslog](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/syslog_destination) | resource |
| [crosswork_system_notification_policies.system](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/system_notification_policies) | resource |
| [crosswork_tags.tag](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/tags) | resource |
| [crosswork_te_flex_algo_affinity.te_flex_algo_affinity](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/te_flex_algo_affinity) | resource |
| [crosswork_te_general_settings.te_general_settings](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/te_general_settings) | resource |
| [crosswork_te_link_affinity.te_link_affinity](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/te_link_affinity) | resource |
| [crosswork_topology_discovery_settings.discovery](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/topology_discovery_settings) | resource |
| [crosswork_trap_destination.trap](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/trap_destination) | resource |
| [crosswork_users.user](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/resources/users) | resource |
| [local_sensitive_file.defaults](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [terraform_data.aaa_changes](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.aaa_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.golden_configuration_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [crosswork_data_gateway_instances.instance](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/data-sources/data_gateway_instances) | data source |
| [crosswork_groupings.device](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/data-sources/groupings) | data source |
| [crosswork_groupings.device_access](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/data-sources/groupings) | data source |
| [crosswork_groupings.port](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/data-sources/groupings) | data source |
| [crosswork_role_catalog.catalog](https://registry.terraform.io/providers/CiscoDevNet/crosswork/latest/docs/data-sources/role_catalog) | data source |
## Modules

No modules.
<!-- END_TF_DOCS -->