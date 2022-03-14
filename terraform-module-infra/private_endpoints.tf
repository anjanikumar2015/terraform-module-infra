resource "azurerm_private_endpoint" "storage" {
    for_each = {
        for k, v in local.storage : k => v if v.private_endpoint && v.account_kind == "StorageV2"
    }
    name                = "${each.key}-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = try(azurerm_storage_account.storage[each.value.storage].id, data.azurerm_storage_account.storage[each.value.storage].id)
    subresource_names              = [ "blob" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.blob.core.windows.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.blob.core.windows.net"].id, azurerm_private_dns_zone.dns["privatelink.blob.core.windows.net"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_private_endpoint" "storage-file" {
    for_each = {
        for k, v in local.storage : k => v if v.private_endpoint && v.account_kind  == "FileStorage"
    }
    name                = "${each.key}-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.storage[each.value.storage].id
    subresource_names              = [ "file" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.file.core.windows.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.file.core.windows.net"].id, azurerm_private_dns_zone.dns["privatelink.file.core.windows.net"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_private_endpoint" "rsv-backup" {
    for_each = {
        for k, v in local.rsv : k => v if v.private_endpoint && v.backup
    }
    name                = "${each.key}-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = azurerm_recovery_services_vault.rsv[each.key].id
    subresource_names              = [ "AzureBackup" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.${each.value.loc}.backup.windowsazure.com"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.${each.value.loc}.backup.windowsazure.com"].id, azurerm_private_dns_zone.dns["privatelink.${each.value.loc}.backup.windowsazure.com"].id),
      try(data.azurerm_private_dns_zone.dns["privatelink.blob.core.windows.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.blob.core.windows.net"].id, azurerm_private_dns_zone.dns["privatelink.blob.core.windows.net"].id),
      try(data.azurerm_private_dns_zone.dns["privatelink.queue.core.windows.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.queue.core.windows.net"].id, azurerm_private_dns_zone.dns["privatelink.queue.core.windows.net"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_private_endpoint" "rsv-siterecovery" {
    for_each = {
        for k, v in local.rsv : k => v if v.private_endpoint && !v.backup
    }
    name                = "${each.key}-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = azurerm_recovery_services_vault.rsv[each.key].id
    subresource_names              = [ "AzureSiteRecovery" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.siterecovery.windowsazure.com"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.siterecovery.windowsazure.com"].id, azurerm_private_dns_zone.dns["privatelink.siterecovery.windowsazure.com"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_private_endpoint" "keyvault" {
    for_each = {
        for k, v in local.kv : k => v if v.private_endpoint
    }
    name                = "${each.key}-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.kv[each.key].id
    subresource_names              = [ "Vault" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.vaultcore.azure.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.vaultcore.azure.net"].id, azurerm_private_dns_zone.dns["privatelink.vaultcore.azure.net"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_private_endpoint" "automation-webhook" {
    for_each = {
        for k, v in local.automation_account : k => v if v.private_endpoint
    }
    name                = "${each.key}-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = azurerm_automation_account.automation_account[each.key].id
    subresource_names              = [ "Webhook" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.azure-automation.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.azure-automation.net"].id, azurerm_private_dns_zone.dns["privatelink.azure-automation.net"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_private_endpoint" "automation-hybid" {
    for_each = {
        for k, v in local.automation_account : k => v if v.private_endpoint
    }
    name                = "${each.key}-hybrid-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-hybrid-privateserviceconnection"
    private_connection_resource_id = azurerm_automation_account.automation_account[each.key].id
    subresource_names              = [ "DSCAndHybridWorker" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.azure-automation.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.azure-automation.net"].id, azurerm_private_dns_zone.dns["privatelink.azure-automation.net"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_monitor_private_link_scope" "log_analytics" {
  for_each = {
    for k, v in local.loganalytic : k => v if v.private_endpoint
  }
  name                              = "${each.key}-endpoint-scope"
  resource_group_name               = each.value.rg
}
resource "azurerm_monitor_private_link_scoped_service" "log_analytics" {
  for_each = {
    for k, v in local.loganalytic : k => v if v.private_endpoint
  }
  name                = "${each.key}-amplsservice"
  resource_group_name = each.value.rg
  scope_name          = azurerm_monitor_private_link_scope.log_analytics[each.key].name
  linked_resource_id  = azurerm_log_analytics_workspace.loganalytics[each.key].id
}
resource "azurerm_private_endpoint" "log_analytics" {
    for_each = {
        for k, v in local.loganalytic : k => v if v.private_endpoint
    }
    name                = "${each.key}-endpoint"
    location            = var.inputs.location
    resource_group_name = each.value.rg
    subnet_id           = data.azurerm_subnet.subnets[each.value.pe_subnet].id

  private_service_connection {
    name                           = "${each.key}-privateserviceconnection"
    private_connection_resource_id = azurerm_monitor_private_link_scope.log_analytics[each.key].id
    subresource_names              = [ "azuremonitor" ]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                  = "${each.key}"
    private_dns_zone_ids  = [ 
      try(data.azurerm_private_dns_zone.dns["privatelink.monitor.azure.com"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.monitor.azure.com"].id, azurerm_private_dns_zone.dns["privatelink.monitor.azure.com"].id),
      try(data.azurerm_private_dns_zone.dns["privatelink.oms.opinsights.azure.com"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.oms.opinsights.azure.com"].id, azurerm_private_dns_zone.dns["privatelink.oms.opinsights.azure.com"].id),
      try(data.azurerm_private_dns_zone.dns["privatelink.ods.opinsights.azure.com"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.ods.opinsights.azure.com"].id, azurerm_private_dns_zone.dns["privatelink.ods.opinsights.azure.com"].id),
      try(data.azurerm_private_dns_zone.dns["privatelink.agentsvc.azure-automation.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.agentsvc.azure-automation.net"].id, azurerm_private_dns_zone.dns["privatelink.agentsvc.azure-automation.net"].id),
      try(data.azurerm_private_dns_zone.dns["privatelink.blob.core.windows.net"].id, data.azurerm_private_dns_zone.dns_remote["privatelink.blob.core.windows.net"].id, azurerm_private_dns_zone.dns["privatelink.blob.core.windows.net"].id)
      ]
  }
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}