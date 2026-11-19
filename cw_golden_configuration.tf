### GOLDEN CONFIGURATION ###

locals {
  golden_configuration    = try(local.crosswork.golden_configuration, {})
  golden_defaults         = try(local.defaults.crosswork.golden_configuration.templates, {})
  golden_global_variables = { for variable in try(local.golden_configuration.global_variables, []) : variable.name => variable }
  golden_templates        = { for template in try(local.golden_configuration.templates, []) : template.name => template }

  # The body of a template is the file <template name>.j2 anywhere under one of the listed directories (subfolders
  # included; the folder is not part of the name, so a name must be unique across all of them). The module reads it with
  # file(), never templatefile(): Terraform does not render it, the controller does. A CRLF line ending becomes LF.
  golden_body_files = flatten([
    for directory in var.golden_configuration_directories : [
      for path in fileset(".", "${directory}/**/*.j2") : { name = trimsuffix(basename(path), ".j2"), path = path }
    ]
  ])
  golden_body_paths = { for file in local.golden_body_files : file.name => file.path... }
  golden_bodies = {
    for name, paths in local.golden_body_paths : name => replace(file(paths[0]), "\r\n", "\n")
  }

  # Values are sent as text (a map as JSON). A secret (with a version) goes write-only, so it stays out of the plan and
  # the state.
  golden_global_variable_values = { for name, variable in local.golden_global_variables : name => {
    type             = try(variable.type, "STRING")
    value            = try(variable.value_version, null) == null ? (can(tostring(variable.value)) ? tostring(variable.value) : jsonencode(variable.value)) : null
    value_wo         = try(variable.value_version, null) != null ? sensitive(can(tostring(variable.value)) ? tostring(variable.value) : jsonencode(variable.value)) : null
    value_wo_version = try(variable.value_version, null)
  } }

  golden_template_variables = { for name, template in local.golden_templates : name => [for variable in try(template.variables, []) : {
    name             = variable.name
    type             = try(variable.type, "STRING")
    value            = try(variable.value_version, null) == null ? (can(tostring(variable.value)) ? tostring(variable.value) : jsonencode(variable.value)) : null
    value_wo         = try(variable.value_version, null) != null ? sensitive(can(tostring(variable.value)) ? tostring(variable.value) : jsonencode(variable.value)) : null
    value_wo_version = try(variable.value_version, null)
  }] }

  # The devices of a template: those it lists and those that apply it. A device named in both is one assignment, and its
  # own values apply.
  golden_applied = flatten([
    for device in local.network_devices : [
      for applied in try(device.golden_configuration.templates, []) : {
        template = applied.name
        device   = device.name
        variables = [for variable in try(applied.variables, []) : {
          name             = variable.name
          type             = try(variable.type, "STRING")
          value            = try(variable.value_version, null) == null ? (can(tostring(variable.value)) ? tostring(variable.value) : jsonencode(variable.value)) : null
          value_wo         = try(variable.value_version, null) != null ? sensitive(can(tostring(variable.value)) ? tostring(variable.value) : jsonencode(variable.value)) : null
          value_wo_version = try(variable.value_version, null)
        }]
      }
    ]
  ])
  golden_template_devices = { for name, template in local.golden_templates : name => merge(
    { for device in try(template.devices, []) : device => [] },
    { for applied in local.golden_applied : applied.device => applied.variables if applied.template == name },
  ) }
  golden_jobs = { for name, devices in local.golden_template_devices : name => devices if length(devices) > 0 }

  # The jobs by tier: the `order` of a template (0 to 9, default 0) puts its job in the resource of that tier, and a tier
  # starts when the one before it has finished.
  golden_job_tiers = { for tier in range(10) : tier => {
    for name, devices in local.golden_jobs : name => devices
    if try(local.golden_templates[name].order, try(local.golden_defaults.order, 0)) == tier
  } }

  # A change to the template body, mode, format or variables, or to a global variable it uses, must reach the unchanged
  # devices too, so the job gets a hash of them. A global variable counts as used when its name is a whole word in the
  # body or the variable names: a text match, not a Jinja parse, so a false match costs one extra re-apply. A secret
  # counts by its version.
  golden_trigger = { for name, template in local.golden_templates : name => sha256(jsonencode({
    body        = try(local.golden_bodies[name], "")
    mode        = try(template.mode, try(local.golden_defaults.mode, "merge"))
    config_type = try(template.config_type, try(local.golden_defaults.config_type, "native"))
    variables = [for variable in try(template.variables, []) : {
      name  = variable.name
      type  = try(variable.type, "STRING")
      value = try(variable.value_version, null) != null ? "version ${variable.value_version}" : (can(tostring(variable.value)) ? tostring(variable.value) : jsonencode(variable.value))
    }]
    globals = { for global_name, global in local.golden_global_variables : global_name => try(global.value_version, null) != null ? "version ${global.value_version}" : (can(tostring(global.value)) ? tostring(global.value) : jsonencode(global.value))
      if length(regexall("\\b${global_name}\\b", join(" ", concat([try(local.golden_bodies[name], "")], [for variable in try(template.variables, []) : variable.name])))) > 0
    }
  })) }
}

resource "terraform_data" "golden_configuration_validation" {
  lifecycle {
    precondition {
      condition     = alltrue([for name, template in local.golden_templates : contains(keys(local.golden_body_paths), name)])
      error_message = "A Golden Configuration template has no body file. Put <template name>.j2 in a directory of `golden_configuration_directories`: ${join(", ", [for name, template in local.golden_templates : name if !contains(keys(local.golden_body_paths), name)])}"
    }
    precondition {
      condition     = alltrue([for name, paths in local.golden_body_paths : length(paths) == 1])
      error_message = "A Golden Configuration template has more than one body file: ${join(", ", flatten([for name, paths in local.golden_body_paths : paths if length(paths) > 1]))}"
    }
  }
}

# Ordering: a template uses the global variables, so they are created first and deleted last: the controller lets a
# variable be deleted while a template uses it. A job comes after the devices and the template, and on a destroy it goes
# first: it removes the configuration from the devices, and the controller refuses to delete an applied template.
resource "crosswork_golden_config_global_variables" "global_variable" {
  for_each         = local.golden_global_variables
  instance         = var.instance
  name             = each.key
  type             = local.golden_global_variable_values[each.key].type
  value            = local.golden_global_variable_values[each.key].value
  value_wo         = local.golden_global_variable_values[each.key].value_wo
  value_wo_version = local.golden_global_variable_values[each.key].value_wo_version
}

resource "crosswork_golden_config_templates" "template" {
  for_each       = local.golden_templates
  instance       = var.instance
  name           = each.key
  description    = try(each.value.description, try(local.golden_defaults.description, null))
  tags           = try(each.value.tags, try(local.golden_defaults.tags, null)) == null ? null : toset(try(each.value.tags, local.golden_defaults.tags))
  mode           = try(each.value.mode, try(local.golden_defaults.mode, null))
  config_type    = try(each.value.config_type, try(local.golden_defaults.config_type, null))
  vendor         = try(each.value.vendor, local.golden_defaults.vendor)
  software_type  = try(each.value.software_type, local.golden_defaults.software_type)
  product_series = toset(each.value.product_series)
  audit          = try(each.value.global_schedule_audit, try(local.golden_defaults.global_schedule_audit, null))
  config         = local.golden_bodies[each.key]
  variables      = length(local.golden_template_variables[each.key]) == 0 ? null : local.golden_template_variables[each.key]
  force_delete   = try(each.value.force_delete, try(local.golden_defaults.force_delete, null))

  depends_on = [
    crosswork_golden_config_global_variables.global_variable,
    terraform_data.golden_configuration_validation
  ]
}

# One job resource per tier
resource "crosswork_golden_config_jobs" "job_0" {
  for_each           = local.golden_job_tiers[0]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_network_devices.network_device,
    crosswork_golden_config_global_variables.global_variable
  ]
}

resource "crosswork_golden_config_jobs" "job_1" {
  for_each           = local.golden_job_tiers[1]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_0
  ]
}

resource "crosswork_golden_config_jobs" "job_2" {
  for_each           = local.golden_job_tiers[2]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_1
  ]
}

resource "crosswork_golden_config_jobs" "job_3" {
  for_each           = local.golden_job_tiers[3]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_2
  ]
}

resource "crosswork_golden_config_jobs" "job_4" {
  for_each           = local.golden_job_tiers[4]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_3
  ]
}

resource "crosswork_golden_config_jobs" "job_5" {
  for_each           = local.golden_job_tiers[5]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_4
  ]
}

resource "crosswork_golden_config_jobs" "job_6" {
  for_each           = local.golden_job_tiers[6]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_5
  ]
}

resource "crosswork_golden_config_jobs" "job_7" {
  for_each           = local.golden_job_tiers[7]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_6
  ]
}

resource "crosswork_golden_config_jobs" "job_8" {
  for_each           = local.golden_job_tiers[8]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_7
  ]
}

resource "crosswork_golden_config_jobs" "job_9" {
  for_each           = local.golden_job_tiers[9]
  instance           = var.instance
  template_name      = crosswork_golden_config_templates.template[each.key].name
  template_config_id = crosswork_golden_config_templates.template[each.key].config_id
  vendor             = try(local.golden_templates[each.key].vendor, local.golden_defaults.vendor)
  product_series     = tolist(local.golden_templates[each.key].product_series)[0]
  mop                = try(local.golden_templates[each.key].mop, local.golden_defaults.mop)
  batch_size         = try(local.golden_templates[each.key].parallel_execution, try(local.golden_defaults.parallel_execution, null))
  error_budget       = try(local.golden_templates[each.key].acceptable_failures, try(local.golden_defaults.acceptable_failures, null))
  tags               = try(local.golden_templates[each.key].job_tags, try(local.golden_defaults.job_tags, null)) == null ? null : toset(try(local.golden_templates[each.key].job_tags, local.golden_defaults.job_tags))
  deployment_timeout = try(local.golden_templates[each.key].deployment_timeout, try(local.golden_defaults.deployment_timeout, null))
  trigger            = local.golden_trigger[each.key]
  devices            = { for device, variables in each.value : device => { variables = length(variables) == 0 ? null : variables } }

  depends_on = [
    crosswork_golden_config_jobs.job_8
  ]
}
