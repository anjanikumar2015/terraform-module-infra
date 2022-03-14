terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 2.78.0"
      configuration_aliases = [azurerm.remote]
    }
  }
}
locals {
  rg = {
    for rg_key, rg_data in try(local.rgs, {}) : rg_key => merge(
      {
        existing = false
      },
      rg_data,
      {
        tags = merge(
          local.tags,
          try(rg_data.tags, {})
        )
      }
    )
  }
}
resource "azurerm_resource_group" "rgs" {
  for_each = {
    for k, v in local.rg : k => v if !v.existing
  }
  name                                          = each.key
  location                                      = var.inputs.location
  tags                                          = each.value.tags
}