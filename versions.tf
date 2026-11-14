terraform {
  # Write-only arguments need Terraform 1.11 or later.
  required_version = ">= 1.11.0"

  # Must be bumped together with the module release tag.
  provider_meta "crosswork" {
    module_name = "NAC/0.1.0"
  }

  required_providers {
    crosswork = {
      source  = "CiscoDevNet/crosswork"
      version = "~> 0.1.0"
    }
    utils = {
      source  = "netascode/utils"
      version = ">= 2.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.3.0"
    }
  }
}
