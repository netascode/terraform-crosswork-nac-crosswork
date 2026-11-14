variable "yaml_directories" {
  description = "List of paths to YAML directories."
  type        = list(string)
  default     = []
}

variable "yaml_files" {
  description = "List of paths to YAML files."
  type        = list(string)
  default     = []
}

variable "model" {
  description = "As an alternative to YAML files, a native Terraform data structure can be provided as well."
  type        = map(any)
  default     = {}
}

variable "instance" {
  description = "Name of the provider instance (controller) the resources are created on. Leave it unset to use the default instance."
  type        = string
  default     = null
}

variable "write_default_values_file" {
  description = "Write all default values to a YAML file. Value is a path pointing to the file to be created."
  type        = string
  default     = ""
}

variable "golden_configuration_directories" {
  description = "List of paths to directories with the Golden Configuration template bodies, one `<template name>.j2` file per template."
  type        = list(string)
  default     = []
}
