### PERFORMANCE POLICIES ###

locals {
  performance_policies_templates = {
    device-health           = "deviceHealth"
    interface-health        = "INTERFACE"
    qos                     = "QOS"
    optical-sfp             = "OpticalSFP"
    optical-zrp             = "OPTICALZRP"
    lsp-traffic             = "SRPOLICY"
    srv6-traffic-accounting = "SRV6LOCATOR"
    gnss                    = "GNSS"
    ptp-synce               = "PTP"
  }

  performance_policies_schemas = {
    memory-pool-utilization  = "MEMORY"
    cpu-utilization          = "CPU"
    environment-temperature  = "ENVTEMP"
    device-availability      = "DVAVAILABILITY"
    statistics               = "CEPMINTERFACE"
    crc                      = "CEPMCRC"
    quality-of-service       = "CEPMQOS"
    optical-sfp              = "OPTICALSFP"
    optics-lane              = "OPTICSLANE"
    otu-controllers-info     = "OTUCONTROLLERSINFO"
    lsp-traffic              = "SRPOLICY"
    transmitted-traffic-rate = "SRV6LOCATOR"
    gnss                     = "CEPMGNSS"
    ptp                      = "CEPMPTP"
    input-quality-level      = "CEPMSYNCE"
  }

  performance_policies_polling = {
    none  = 0
    "5m"  = 300
    "10m" = 600
    "15m" = 900
    "30m" = 1800
    "1h"  = 3600
  }

  performance_policies_metrics = {
    memory-pool-utilization   = "memoryUtilization"
    cpu-utilization           = "cpuUtilization"
    environment-temperature   = "envTemperatureX100"
    device-inlet-temperature  = "envTemperatureInletX100"
    in-traffic-rate           = "ifInBitsRate"
    out-traffic-rate          = "ifOutBitsRate"
    in-packet-rate            = "ifInPktsRate"
    out-packet-rate           = "ifOutPktsRate"
    in-packet-drops           = "ifInDiscardsPercent"
    out-packet-drops          = "ifOutDiscardsPercent"
    in-packet-drops-rate      = "ifInDiscardsRate"
    out-packet-drops-rate     = "ifOutDiscardsRate"
    in-packet-errors          = "ifInErrorsPercent"
    out-packet-errors         = "ifOutErrorsPercent"
    in-packet-errors-rate     = "ifInErrorsRate"
    out-packet-errors-rate    = "ifOutErrorsRate"
    in-traffic-utilization    = "ifInUtilization"
    out-traffic-utilization   = "ifOutUtilization"
    crc-errors                = "crcPercentage"
    crc-errors-rate           = "crc"
    dropped-traffic           = "dropBitsPercent"
    dropped-traffic-rate      = "dropBitsRate"
    dropped-packets           = "dropPktsPercent"
    dropped-packets-rate      = "dropPktsRate"
    received-optical-power    = "rxPower"
    transmitted-optical-power = "txPower"
    transmitted-bias-current  = "txBias"
    voltage                   = "voltage"
    temperature               = "temperature"
    maximum-receive-power     = "maxReceivePower"
    maximum-transmit-power    = "maxTransmitPower"
    minimum-receive-power     = "minReceivePower"
    minimum-transmit-power    = "minTransmitPower"
    average-receive-power     = "receivePower"
    average-transmit-power    = "transmitPower"
    q-factor                  = "qfactor"
    q-margin                  = "qmargin"
    pre-fec-ber               = "preFecBer"
    post-fec-ber              = "postFecBer"
    error-corrected-bits      = "ec"
    uncorrectable-words       = "uc"
    transmitted-traffic-rate  = "outBitRate"
    out-packets-rate          = "outPktsRate"
  }

  performance_policies_operators = {
    equals                 = "EQ"
    greater-than           = "GT"
    greater-than-or-equals = "GE"
    less-than              = "LT"
    less-than-or-equals    = "LE"
  }

  performance_policies = {
    for policy in try(local.crosswork.device_management.performance_policies, []) : policy.name => {
      name            = policy.name
      description     = try(policy.description, local.defaults.crosswork.device_management.performance_policies.description, null)
      contact         = try(policy.contact, local.defaults.crosswork.device_management.performance_policies.contact, null)
      policy_template = local.performance_policies_templates[policy.type]
      active          = try(policy.active, local.defaults.crosswork.device_management.performance_policies.active, null)
      devices         = try(length(policy.devices) == 0, true) ? null : [for device in policy.devices : crosswork_network_devices.network_device[device].id]
      device_groups   = try(length(policy.device_groups) == 0, true) ? null : [for path in policy.device_groups : local.device_group_ids[join("/", [for segment in split("/", path) : replace(segment, "%", "%25")])]]
      port_groups     = try(length(policy.port_groups) == 0, true) ? null : [for group in policy.port_groups : crosswork_port_groups.port_group[group].id]
      schema_intervals = [
        for metric in policy.metrics : {
          schema  = local.performance_policies_schemas[metric.name]
          seconds = local.performance_policies_polling[metric.polling_frequency]
        }
      ]
      # The thresholds of every group go into one map by the name of the metric, which is unique in a policy.
      thresholds = length(flatten([for metric in policy.metrics : try(metric.thresholds, [])])) == 0 ? null : merge([
        for metric in policy.metrics : {
          for threshold in try(metric.thresholds, []) : local.performance_policies_metrics[threshold.metric] => {
            conditions = [
              for condition in threshold.conditions : {
                relation = local.performance_policies_operators[condition.operator]
                value    = tostring(condition.value)
                count    = condition.count
                # An event is sent with the severity INFORMATION; an alarm severity is upper case for Crosswork.
                severity  = try(condition.type, local.defaults.crosswork.device_management.performance_policies.metrics.thresholds.conditions.type) == "event" ? "INFORMATION" : upper(condition.severity)
                match_cos = try(condition.match_cos, null)
              }
            ]
          }
        }
      ]...)
    }
  }
}

resource "crosswork_performance_policies" "policy" {
  for_each         = local.performance_policies
  instance         = var.instance
  name             = each.value.name
  description      = each.value.description
  contact          = each.value.contact
  policy_template  = each.value.policy_template
  active           = each.value.active
  devices          = each.value.devices
  device_groups    = each.value.device_groups
  port_groups      = each.value.port_groups
  schema_intervals = each.value.schema_intervals
  thresholds       = each.value.thresholds
}
