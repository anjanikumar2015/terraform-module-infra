
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "primary" {}
data "azurerm_resource_group" "rgs" {
  for_each = {
    for k, v in local.rg : k => v if v.existing
  }
  name                                          = each.key
}
data "azurerm_virtual_network" "vnets" {
    for_each = {
        for k, v in local.vnets : k => v
    }
    name                                        = each.key
    resource_group_name                         = each.value.rg
    depends_on = [
        azurerm_virtual_network.vnets
    ]
}
data "azurerm_virtual_network" "vnet_remote" {
    for_each = {
        for peer in local.peers : peer.name => peer if peer.remote_peer.remote == true
    }
    provider                                    = azurerm.remote
    name                                        = each.value.remote_vnet
    resource_group_name                         = each.value.remote_rg
    depends_on = [
        azurerm_virtual_network.vnets
    ]
}
data "azurerm_subnet" "subnets" {
  for_each = {
    for subnet in local.subnets : subnet.subnet => subnet
  }
    name                                        = each.key
    resource_group_name                         = each.value.rg
    virtual_network_name                        = each.value.virtual_network_name
    depends_on = [
      azurerm_virtual_network.vnets, 
      azurerm_subnet.subnets
    ]
}
data "azurerm_netapp_account" "netapp" {
  for_each = {
  for k, v in try(local.account, {}) : k => v if !v.existing && !v.remote
  }
  name                                            = each.key
  resource_group_name                             = each.value.rg
  depends_on = [
    azurerm_netapp_account.netapp
  ]
}
data "azurerm_netapp_pool" "netapp_remote" {
  for_each = {
  for k, v in try(local.pool, {}) : k => v if v.existing && v.remote
  }
  provider                                        = azurerm.remote
  name                                            = each.key
  account_name                                    = each.value.account
  resource_group_name                             = each.value.rg
}
data "azurerm_netapp_account" "netapp_remote" {
  for_each = {
  for k, v in try(local.account, {}) : k => v if v.existing && v.remote
  }
  provider                                        = azurerm.remote
  name                                            = each.key
  resource_group_name                             = each.value.rg
}
data "azurerm_storage_account" "storage" {
  for_each = {
    for k, v in local.storage : k => v if v.existing && !v.remote
  }
  name                                          = each.key
  resource_group_name                           = each.value.rg
}
data "azurerm_log_analytics_workspace" "loganalytics" {
  for_each = {
    for la in try(local.loganalytic, {}) : la.name => la if la.existing && !la.remote
  }
  name                                          = each.key
  resource_group_name                           = each.value.rg
}
data "azurerm_storage_account" "storage_remote" {
  for_each = {
    for k, v in local.storage : k => v if v.existing && v.remote
  }
  provider                                      = azurerm.remote
  name                                          = each.key
  resource_group_name                           = each.value.rg
}
data "azurerm_log_analytics_workspace" "loganalytics_remote" {
  for_each = {
    for la in try(local.loganalytic, {}) : la.name => la if la.existing && la.remote
  }
  provider                                      = azurerm.remote
  name                                          = each.key
  resource_group_name                           = each.value.rg
}
data "azurerm_recovery_services_vault" "rsv" {
  for_each = {
    for rsv in try(local.rsv, {}) : rsv.name => rsv
  }
  name                                        = each.key
  resource_group_name                         = each.value.rg
  depends_on = [
      azurerm_recovery_services_vault.rsv
  ]
}
data "azurerm_key_vault" "kv" {
    for_each = {
    for kv in try(local.kv, {}) : kv.name => kv
  }
  name                                        = each.value.name
  resource_group_name                         = each.value.rg
  depends_on = [
    azurerm_key_vault.kv
  ]
}
data "azurerm_network_security_group" "nsgs" {
   for_each = {
    for k, v in try(local.nsg, {}) : k => v
  }
  name                                          = each.key
  resource_group_name                           = each.value.rg
  depends_on = [
    azurerm_network_security_group.nsgs
  ]  
}
data "azurerm_virtual_network_gateway" "vng" {
   for_each = {
    for k, v in try(local.vngs, {}) : k => v
  }
  name                                          = each.key
  resource_group_name                           = each.value.rg
  depends_on = [
    azurerm_virtual_network_gateway.vng
  ]  
}
data "azurerm_automation_account" "automation_account" {
  for_each = {
    for k, v in try(local.mgmt.automation, {}) : k => v
  }
  name                                          = each.key
  resource_group_name                           = each.value.rg
  depends_on = [
    azurerm_automation_account.automation_account
  ]
}
data "azurerm_private_dns_zone" "dns" {
  for_each = {
      for dns in local.private_dns : dns.zone => dns if dns.existing && !dns.remote
  }
  name                                         = each.value.zone
  resource_group_name                          = each.value.rg
}
data "azurerm_private_dns_zone" "dns_remote" {
  for_each = {
      for dns in local.private_dns : dns.zone => dns if dns.existing && dns.remote
  }
  provider                                     = azurerm.remote
  name                                         = each.value.zone
  resource_group_name                          = each.value.rg
}
data "azurerm_monitor_diagnostic_categories" "nsgs" {
  for_each = {
    for k, v in try(local.nsg, {}) : k => v
  }
  resource_id                                   = data.azurerm_network_security_group.nsgs[each.key].id
  depends_on = [
    azurerm_network_security_group.nsgs
  ]
}
data "azurerm_monitor_diagnostic_categories" "vnets" {
  for_each = {
    for k, v in try(local.vnets, {}) : k => v
  }
  resource_id                                   = data.azurerm_virtual_network.vnets[each.key].id
  depends_on = [
    azurerm_virtual_network.vnets
  ]
}
data "azurerm_monitor_diagnostic_categories" "vngs" {
  for_each = {
    for k, v in try(local.vngs, {}) : k => v
  }
  resource_id                                   = data.azurerm_virtual_network_gateway.vng[each.key].id
  depends_on = [
    azurerm_virtual_network_gateway.vng
  ]
}
data "azurerm_monitor_diagnostic_categories" "automation_account" {
  for_each = {
    for k, v in try(local.mgmt.automation, {}) : k => v
  }
  resource_id                                 = data.azurerm_automation_account.automation_account[each.key].id
  depends_on = [
    azurerm_automation_account.automation_account
  ]
}
data "azurerm_monitor_diagnostic_categories" "rsv" {
  for_each = {
    for k, v in try(local.rsv, {}) : k => v
  }
  resource_id                                 = data.azurerm_recovery_services_vault.rsv[each.key].id
  depends_on = [
    azurerm_recovery_services_vault.rsv
  ]
}
data "azurerm_monitor_diagnostic_categories" "kv" {
  for_each = {
    for k, v in try(local.kv, {}) : k => v
  }
  resource_id                                 = data.azurerm_key_vault.kv[each.key].id
  depends_on = [
    azurerm_key_vault.kv
  ]
}
data "azurerm_network_watcher" "network_watcher" {
  for_each = {
      for watcher in try(local.watcher, {}) : watcher.name => watcher if watcher.existing && !watcher.remote
  }
  name                                          = each.value.name
  resource_group_name                           = each.value.rg
}
data "azurerm_network_watcher" "network_watcher_remote" {
  for_each = {
      for watcher in try(local.watcher, {}) : watcher.name => watcher if watcher.existing && watcher.remote
  }
  provider                                     = azurerm.remote
  name                                          = each.value.name
  resource_group_name                           = each.value.rg
}
data "azurerm_firewall" "firewalls" {
  for_each = local.firewalls

  name                = each.key
  resource_group_name = each.value.rg

  depends_on = [
    azurerm_firewall.firewalls
  ]
}
data "azuread_service_principal" "rsv" {
  for_each = {
    for k, v in try(local.rsv, {}) : k => v if v.private_endpoint && v.backup
  }
  display_name                        = each.key

  depends_on = [
    azurerm_recovery_services_vault.rsv
  ]
}
data "azurerm_public_ip" "pub_ips" {
  for_each = local.pub_ips
  name                                        = each.key
  resource_group_name                         = each.value.rg
  depends_on = [
    azurerm_public_ip.pub_ips
  ]
}
data "azurerm_monitor_diagnostic_categories" "pub_ips" {
  for_each = {
    for k, v in try(local.pub_ips, {}) : k => v
  }
  resource_id                                   = data.azurerm_public_ip.pub_ips[each.key].id
  depends_on = [
    azurerm_public_ip.pub_ips
  ]
}
data "azurerm_monitor_diagnostic_categories" "bastion" {
  for_each = {
    for k, v in try(local.bastion, {}) : k => v
  }
  resource_id                                   = azurerm_bastion_host.bastion[each.key].id
  depends_on = [
    azurerm_bastion_host.bastion
  ]
}