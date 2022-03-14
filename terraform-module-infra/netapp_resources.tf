locals {
  account = {
    for k, v in try(local.netapp.accounts, {}) : k => merge(
      v,
      {
        existing                                        = try(v.existing, false)
        remote                                          = try(v.remote, false)
      }
    )
  }
  pool = flatten([
    for account_key, account_data in try(local.account, {}) : [
      for pool_key, pool_data in try(local.netapp.pools) : merge(
        pool_data,
        {
          name                                            = pool_key
          service_level                                   = try(pool_data.service_level, "Standard")
          size_in_tb                                      = try(pool_data.size_in_tb, 4)
          existing                                        = try(pool_data.existing, false)
          remote                                          = try(pool_data.remote, false)
        },
        account_data,
        {
          account                                         = account_key
        }
      )
    ]
  ])
  volume = flatten([
    for account_key, account_data in try(local.account, {}) : [
      for volume_key, volume_data in try(local.netapp.volumes) : merge(
        volume_data,
        {
          name                                            = volume_key
          service_level                                   = try(volume_data.service_level, "Standard")
          storage_quota_in_gb                             = try(volume_data.storage_quota_in_gb, 100)
          protocols                                       = try(volume_data.protocols, ["NFSv4.1"])
        },
        account_data,
        {
          account                                         = account_key
        }
      )
    ]
  ])
}
resource "azurerm_netapp_account" "netapp" {
  for_each = {
    for k, v in try(local.account, {}) : k => v if !v.existing
  }
  name                                            = each.key
  location                                        = var.inputs.location
  resource_group_name                             = each.value.rg

  depends_on = [
    azurerm_resource_group.rgs
  ]
  tags                                            = local.tags
}
resource "azurerm_netapp_pool" "netapp" {
  for_each = {
    for pool in try(local.pool, {}) : pool.name => pool if !pool.existing
  }
  name                                            = each.value.name
  account_name                                    = data.azurerm_netapp_account.netapp[each.value.account].name
  location                                        = var.inputs.location
  resource_group_name                             = each.value.rg
  service_level                                   = each.value.service_level
  size_in_tb                                      = each.value.size_in_tb

  depends_on = [
    azurerm_netapp_account.netapp
  ]
  tags                                            = local.tags
}
resource "azurerm_netapp_volume" "netapp" {
  for_each = {
    for volume in try(local.volume, {}) : volume.name => volume
  }
  name                                          = each.value.name
  location                                      = var.inputs.location
  resource_group_name                           = each.value.rg
  account_name                                  = try(data.azurerm_netapp_account.netapp[each.value.account].name, data.azurerm_netapp_account.netapp_remote[each.value.account].name)
  pool_name                                     = try(azurerm_netapp_pool.netapp[each.value.pool].name, data.azurerm_netapp_pool.netapp_remote[each.value.pool].name)
  volume_path                                   = try(each.value.volume_path, each.value.volume)
  service_level                                 = each.value.service_level
  subnet_id                                     = data.azurerm_subnet.subnets[each.value.subnet].id
  storage_quota_in_gb                           = each.value.storage_quota_in_gb
  protocols                                     = each.value.protocols
  dynamic "export_policy_rule" {
    for_each = try(each.value.export_policy_rule, [])

    content {
      rule_index                                = try(export_policy_rule.value.rule_index, 1)
      allowed_clients                           = export_policy_rule.value.allowed_clients
      unix_read_write                           = try(export_policy_rule.value.unix_read_write, true)
      protocols_enabled                         = each.value.protocols
      root_access_enabled                       = try(export_policy_rule.value.root_access_enabled, false)
    }
  }
  depends_on = [
    azurerm_netapp_pool.netapp,
    azurerm_subnet.subnets
  ]
  lifecycle {
    ignore_changes = [
      subnet_id,
      storage_quota_in_gb 
    ]
  }
  tags                                          = local.tags
}