locals {
    watcher = {
        for watcher_key, watcher_data in try(local.inputs.network_watchers, {}) : watcher_key => merge(
            {
            name                                            = watcher_key
            location                                        = try(watcher_data.location, var.inputs.location)
            rg                                              = watcher_data.rg
            existing                                        = try(watcher_data.existing, false)
            remote                                          = try(watcher_data.remote, false)
            },
            watcher_data
        )
    }
    nsg_flow = flatten([
        for nsg_key, nsg_data in try(local.nsgs, {}) : [
            for flow_key, flow_data in try(nsg_data.network_watcher, {}) : merge(
                flow_data,
                {
                    name                                       = flow_key
                    storage                                    = flow_data.storage
                },
                nsg_data,
                {
                    nsg                                        = nsg_key
                    rg                                         = nsg_data.rg
                }
            )
        ]
    ])
    nsg_diag = {
        for diag_key, diag_data in try(local.nsg, {}) : diag_key => merge(
            {
                rg                                              = diag_data.rg
            },
            diag_data,
            {
                name               = "${diag_key}-diags"
                target_resource_id = azurerm_network_security_group.nsgs[diag_key].id
                logs               = data.azurerm_monitor_diagnostic_categories.nsgs[diag_key].logs
                metrics            = data.azurerm_monitor_diagnostic_categories.nsgs[diag_key].metrics
                enabled            = true
                retention_policy = {
                    enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
                    days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
                }
                log_analytics_workspace_id = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
                storage_account_id         = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
            }
        ) if(try(diag_data.diagnostics, {}) != {})
    }
    vnet_diag = {
        for diag_key, diag_data in try(local.vnets, {}) : diag_key => merge(
            {
                name               = "${diag_key}-diag"
                target_resource_id = azurerm_virtual_network.vnets[diag_key].id
                logs               = data.azurerm_monitor_diagnostic_categories.vnets[diag_key].logs
                metrics            = data.azurerm_monitor_diagnostic_categories.vnets[diag_key].metrics
                enabled            = true
                retention_policy = {
                    enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
                    days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
                }
                    log_analytics_workspace_id = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
                    storage_account_id         = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
            }
        ) if(try(diag_data.diagnostics, {}) != {})
    }
    vng_diag = {
      for diag_key, diag_data in try(local.vngs, {}) : diag_key => merge(
        {
          name               = "${diag_key}-diag"
          target_resource_id = azurerm_virtual_network_gateway.vng[diag_key].id
          logs               = data.azurerm_monitor_diagnostic_categories.vngs[diag_key].logs
          metrics            = data.azurerm_monitor_diagnostic_categories.vngs[diag_key].metrics
          enabled            = true
          retention_policy = {
              enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
              days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
          }
          log_analytics_workspace_id = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
          storage_account_id         = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
        }
      ) if(try(diag_data.diagnostics, {}) != {})
    }
    aa_diag = {
      for diag_key, diag_data in try(local.mgmt.automation, {}) : diag_key => merge(
        {
          name                       = "${diag_key}-diag"
          target_resource_id         = azurerm_automation_account.automation_account[diag_key].id
          logs                       = data.azurerm_monitor_diagnostic_categories.automation_account[diag_key].logs
          metrics                    = data.azurerm_monitor_diagnostic_categories.automation_account[diag_key].metrics
          enabled                    = true
          retention_policy = {
              enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
              days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
          }
          log_analytics_workspace_id   = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
          storage_account_id          = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
        }
      ) if(try(diag_data.diagnostics, {}) != {})
    }
    rsv_diag = {
      for diag_key, diag_data in try(local.rsv, {}) : diag_key => merge(
        {
          name                       = "${diag_key}-diag"
          target_resource_id         = azurerm_recovery_services_vault.rsv[diag_key].id
          logs                       = data.azurerm_monitor_diagnostic_categories.rsv[diag_key].logs
          metrics                    = data.azurerm_monitor_diagnostic_categories.rsv[diag_key].metrics
          enabled                    = true
          retention_policy = {
              enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
              days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
          }
          log_analytics_workspace_id   = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
          storage_account_id          = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
        }
      ) if(try(diag_data.diagnostics, {}) != {})
    }
    kv_diag = {
      for diag_key, diag_data in try(local.kv, {}) : diag_key => merge(
        {
          name                       = "${diag_key}-diag"
          target_resource_id         = azurerm_key_vault.kv[diag_key].id
          logs                       = data.azurerm_monitor_diagnostic_categories.kv[diag_key].logs
          metrics                    = data.azurerm_monitor_diagnostic_categories.kv[diag_key].metrics
          enabled                    = true
          retention_policy = {
              enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
              days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
          }
          log_analytics_workspace_id   = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
          storage_account_id          = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
        }
      ) if(try(diag_data.diagnostics, {}) != {})
    }
    pub_ip_diag = {
      for diag_key, diag_data in try(local.inputs.public_ips, {}) : diag_key => merge(
          {
            name               = "${diag_key}-diag"
            target_resource_id = data.azurerm_public_ip.pub_ips[diag_key].id
            logs               = data.azurerm_monitor_diagnostic_categories.pub_ips[diag_key].logs
            metrics            = data.azurerm_monitor_diagnostic_categories.pub_ips[diag_key].metrics
            diagnostics        = try(diag_data.diagnostics, false)
            enabled            = true
            retention_policy = {
                enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
                days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
          }
          log_analytics_workspace_id   = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
          storage_account_id          = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
        }
      ) if(try(diag_data.diagnostics, {}) != {})
    }
    bastion_diag = {
      for diag_key, diag_data in try(local.inputs.bastion, {}) : diag_key => merge(
          {
            name               = "${diag_key}-diag"
            target_resource_id = azurerm_bastion_host.bastion[diag_key].id
            logs               = data.azurerm_monitor_diagnostic_categories.bastion[diag_key].logs
            metrics            = data.azurerm_monitor_diagnostic_categories.bastion[diag_key].metrics
            diagnostics        = try(diag_data.diagnostics, false)
            enabled            = true
            retention_policy = {
                enabled = try(diag_data.diagnostics.storage, null) != null ? true : false
                days    = try(diag_data.diagnostics.storage, null) != null ? try(diag_data.diagnostics.retention, 30) : null
          }
          log_analytics_workspace_id   = try(data.azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[diag_data.diagnostics.workspace].id, azurerm_log_analytics_workspace.loganalytics[diag_data.diagnostics.workspace].id, null)
          storage_account_id          = try(data.azurerm_storage_account.storage[diag_data.diagnostics.storage].id, data.azurerm_storage_account.storage_remote[diag_data.diagnostics.storage].id, azurerm_storage_account.storage[diag_data.diagnostics.storage].id, null)
        }
      ) if(try(diag_data.diagnostics, {}) != {})
    }
}
resource "azurerm_network_watcher" "network_watcher" {
    for_each = {
        for watcher in try(local.watcher, {}) : watcher.name => watcher if !watcher.existing
    }
    name                                                    = each.value.name
    location                                                = each.value.location
    resource_group_name                                     = each.value.rg
    depends_on = [
        azurerm_resource_group.rgs
    ]
}
resource "azurerm_network_watcher_flow_log" "nsgs" {
  for_each = {
    for k, v in try(local.nsg_flow, {}) : k => v
  }
  network_watcher_name                                    = try(azurerm_network_watcher.network_watcher[each.value.name].name, data.azurerm_network_watcher.network_watcher[each.value.name].name, data.azurerm_network_watcher.network_watcher_remote[each.value.name].name)
  resource_group_name                                     = try(azurerm_network_watcher.network_watcher[each.value.name].resource_group_name, data.azurerm_network_watcher.network_watcher[each.value.name].resource_group_name, data.azurerm_network_watcher.network_watcher_remote[each.value.name].resource_group_name)
  network_security_group_id                               = data.azurerm_network_security_group.nsgs[each.value.nsg].id
  storage_account_id                                      = try(data.azurerm_storage_account.storage[each.value.storage].id, data.azurerm_storage_account.storage_remote[each.value.storage].id, azurerm_storage_account.storage[each.value.storage].id)
  enabled                                                 = true
  retention_policy {
      enabled                                             = true
      days                                                = 7
  }
  traffic_analytics {
      enabled                                             = true
      workspace_id                                        = try(data.azurerm_log_analytics_workspace.loganalytics[each.value.workspace].workspace_id, data.azurerm_log_analytics_workspace.loganalytics_remote[each.value.workspace].workspace_id, azurerm_log_analytics_workspace.loganalytics[each.value.workspace].workspace_id)
      workspace_region                                    = try(data.azurerm_log_analytics_workspace.loganalytics[each.value.workspace].location, data.azurerm_log_analytics_workspace.loganalytics_remote[each.value.workspace].location, azurerm_log_analytics_workspace.loganalytics[each.value.workspace].location)
      workspace_resource_id                               = try(data.azurerm_log_analytics_workspace.loganalytics[each.value.workspace].id, data.azurerm_log_analytics_workspace.loganalytics_remote[each.value.workspace].id, azurerm_log_analytics_workspace.loganalytics[each.value.workspace].id)
      interval_in_minutes                                 = 10
  }
  lifecycle {
    ignore_changes = [
      network_security_group_id
    ]
  }
}
resource "azurerm_monitor_diagnostic_setting" "nsgs" {
  for_each = local.nsg_diag
  name                                                      = each.value.name
  target_resource_id                                        = each.value.target_resource_id
  log_analytics_workspace_id                                = each.value.log_analytics_workspace_id
  storage_account_id                                        = each.value.storage_account_id
  dynamic "log" {
    for_each = each.value.logs
    content {
      category                                              = log.value
      enabled                                               = each.value.enabled
      retention_policy {
        enabled                                             = each.value.retention_policy.enabled
        days                                                = each.value.retention_policy.days
      }
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category                                              = metric.value
      enabled                                               = each.value.enabled
      retention_policy {
        enabled                                             = each.value.retention_policy.enabled
        days                                                = each.value.retention_policy.days
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "vnets" {
  for_each = local.vnet_diag
  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id
  storage_account_id         = each.value.storage_account_id

  dynamic "log" {
    for_each = each.value.logs
    content {
      category = log.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "vngs" {
  for_each = local.vng_diag
  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id
  storage_account_id         = each.value.storage_account_id

  dynamic "log" {
    for_each = each.value.logs
    content {
      category = log.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "automation_account" {
  for_each = local.aa_diag

  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id
  storage_account_id         = each.value.storage_account_id
  
  dynamic "log" {
    for_each = each.value.logs
    content {
      category = log.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy_enabled
        days    = each.value.retention_policy_days
      }
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy_enabled
        days    = each.value.retention_policy_days
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "rsv" {
  for_each = local.rsv_diag

  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id
  storage_account_id         = each.value.storage_account_id
  
  dynamic "log" {
    for_each = each.value.logs
    content {
      category = log.value
      enabled  = each.value.enabled
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value
      enabled  = each.value.enabled
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "kv" {
  for_each = local.kv_diag

  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id
  storage_account_id         = each.value.storage_account_id
  
  dynamic "log" {
    for_each = each.value.logs
    content {
      category = log.value
      enabled  = each.value.enabled
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value
      enabled  = each.value.enabled
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "pub_ips" {
  for_each = local.pub_ip_diag

  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id
  storage_account_id         = each.value.storage_account_id

  dynamic "log" {
    for_each = each.value.logs
    content {
      category = log.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
}
resource "azurerm_monitor_diagnostic_setting" "bastion" {
  for_each = local.bastion_diag

  name                       = each.value.name
  target_resource_id         = each.value.target_resource_id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id
  storage_account_id         = each.value.storage_account_id

  dynamic "log" {
    for_each = each.value.logs
    content {
      category = log.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
  dynamic "metric" {
    for_each = each.value.metrics
    content {
      category = metric.value
      enabled  = each.value.enabled
      retention_policy {
        enabled = each.value.retention_policy.enabled
        days    = each.value.retention_policy.days
      }
    }
  }
}