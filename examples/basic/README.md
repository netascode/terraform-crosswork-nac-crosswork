<!-- BEGIN_TF_DOCS -->
# Cisco Crosswork Example

Set environment variables pointing to Crosswork:

```bash
export CW_URL=https://10.1.1.1
export CW_USERNAME=admin
export CW_PASSWORD=Cisco123
```

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ terraform apply
```

Note that this example will create resources. Resources can be destroyed with `terraform destroy`.

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
    provider_profiles:
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
<!-- END_TF_DOCS -->