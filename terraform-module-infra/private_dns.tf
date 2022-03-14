locals {
  private_dns = flatten([
    for dns in try(local.inputs.private_dns, {}) : [
      for zone in try(dns.zones, []) : [
        for vnet in try(dns.vnets, []) :
        {
          rg                                  = dns.rg
          registration_enabled                = try(dns.registration_enabled, false)
          existing                            = try(dns.existing, false)
          remote                              = try(dns.remote, false)
          vnet                                = vnet
          zone                                = zone
          link                                = try(dns.link, false)
        }
      ]
    ]
  ])
}
resource "azurerm_private_dns_zone" "dns" {
  for_each = {
      for dns in local.private_dns : dns.zone => dns if !dns.existing
  }
  name                                    = each.value.zone
  resource_group_name                     = each.value.rg
  depends_on = [
      azurerm_resource_group.rgs
  ]
}
resource "azurerm_private_dns_zone_virtual_network_link" "dns" {
  for_each = {
      for dns in local.private_dns : dns.zone => dns if dns.link
  }
  name                                    = "${each.value.vnet}-${each.value.zone}-dns"
  resource_group_name                     = each.value.rg
  private_dns_zone_name                   = try(data.azurerm_private_dns_zone.dns[each.value.zone].name, data.azurerm_private_dns_zone.dns_remote[each.value.zone].name, azurerm_private_dns_zone.dns[each.value.zone].name)
  virtual_network_id                      = azurerm_virtual_network.vnets[each.value.vnet].id
  registration_enabled                    = each.value.registration_enabled
  lifecycle {
    ignore_changes = [private_dns_zone_name]
  }
}