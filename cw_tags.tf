### TAGS ###

locals {
  tags = try(local.crosswork.administration.tags, [])
}

# User-defined tags. System and internal tags belong to the controller and are never declared.
resource "crosswork_tags" "tag" {
  for_each = { for tag in local.tags : tag.name => tag }
  instance = var.instance
  name     = each.value.name
  category = each.value.category
}
