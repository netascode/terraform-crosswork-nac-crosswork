module "crosswork" {
  source  = "netascode/nac-crosswork/crosswork"
  version = "0.1.0"

  yaml_files = ["administration.yaml", "device_management.yaml"]
}
