output "default_values" {
  description = "All default values."
  value       = local.defaults
}

output "model" {
  description = "Full model with the write-only secrets omitted. Secrets without a `_version` are still included, so the value is marked sensitive."
  value       = local.exported_model
  sensitive   = true
}
