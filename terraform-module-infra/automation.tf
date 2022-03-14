locals {
  automation_account = {
    for k, v in try(local.mgmt.automation, {}) : k => merge(
      {
          sku_name                           = "Basic"
      },
      v,
    )
  }
}
resource "azurerm_automation_account" "automation_account" {
  for_each = local.automation_account
  name                                      = each.key
  location                                  = var.inputs.location
  resource_group_name                       = each.value.rg
  sku_name                                  = each.value.sku_name
  depends_on = [
      azurerm_resource_group.rgs
  ]
}