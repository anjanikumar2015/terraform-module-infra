locals {
  role = {
    for k, v in try(local.rbac, {}) : k => merge(
      {
        existing                                = false
        actions                                 = []
        notactions                              = []
        assignablescopes                        = []
        description                             = "Custom RBAC Role"
        spn                                     = null
      },
      v,
    )
  }
  sec = {
        for k, v in try(local.security, {}) : k => merge(
      {
        tier                                    = "Free"
        auto_provision                          = "Off"
        resource_type                           = "VirtualMachines"
      },
      v,
    )
  }
}
resource "azurerm_security_center_subscription_pricing" "security" {
  for_each = {
    for k, v in try(local.sec, {}) : k => v 
  }
    tier                                        = each.value.tier
    resource_type                               = local.inputs.security_center.resource_type
}
resource "azurerm_security_center_workspace" "security" {
    count                                       = local.sec != {} ? 1 : 0
    scope                                       = data.azurerm_subscription.primary.id
    workspace_id                                = try(data.azurerm_log_analytics_workspace.loganalytics[local.inputs.security_center.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[local.inputs.security_center.workspace].id, azurerm_log_analytics_workspace.loganalytics[local.inputs.security_center.workspace].id, null)
    depends_on = [
        azurerm_security_center_subscription_pricing.security
  ]
}
resource "azurerm_security_center_auto_provisioning" "security" {
  count                                         = local.sec != {} ? 1 : 0
  auto_provision                                = try(local.inputs.security_center.auto_provision, "Off")
}
resource "azurerm_role_definition" "rbac" {
  for_each = {
    for k, v in try(local.role, {}) : k => v if !v.existing
  }
  name                                          = each.key
  scope                                         = data.azurerm_subscription.primary.id
  description                                   = each.value.description
  permissions {
    actions     = each.value.actions
    not_actions = each.value.notactions
  }
  assignable_scopes = [
    data.azurerm_subscription.primary.id
  ]
}
resource "azurerm_role_assignment" "rbac" {
  for_each = {
    for k, v in try(local.role, {}) : k => v if v.spn != null
  }
  scope                                       = data.azurerm_subscription.primary.id
  role_definition_id                          = azurerm_role_definition.rbac[each.key].role_definition_resource_id
  principal_id                                = data.azurerm_client_config.current.object_id
}
resource "azurerm_role_assignment" "rsv" {
  for_each = {
    for k, v in try(local.rsv, {}) : k => v if v.private_endpoint && v.backup
  }
  scope                                       = data.azurerm_resource_group.rgs[each.value.rg].id
  role_definition_name                        = "Contributor"
  principal_id                                = data.azuread_service_principal.rsv[each.key].object_id
}