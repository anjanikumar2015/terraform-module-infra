# locals {
#   nat_gateways = {
#     for k, v in local.networks : k => merge(
#       {},
#       v,
#       {
#         network_name = k
#         gw = {
#           name                    = "${k}-ngw"
#           sku_name                = "Standard"
#           idle_timeout_in_minutes = 10
#         }
#         ip = {
#           name              = "${k}-ngw-pip"
#           allocation_method = "Static"
#           sku               = "Standard"
#         }
#       }
#     ) if v.nat_gateway_required
#   }
# }
# resource "azurerm_public_ip" "nat_gateways" {
#   for_each = local.nat_gateways
#   name                = each.value.ip.name
#   location            = each.value.location
#   resource_group_name = data.azurerm_resource_group.resource_group[each.value.resource_group_name].name
#   allocation_method   = each.value.ip.allocation_method
#   sku                 = each.value.ip.sku
# }
# resource "azurerm_nat_gateway" "nat_gateways" {
#   for_each = local.nat_gateways

#   name                    = each.value.gw.name
#   location                = each.value.location
#   resource_group_name     = data.azurerm_resource_group.resource_group[each.value.resource_group_name].name
#   sku_name                = each.value.gw.sku_name
#   idle_timeout_in_minutes = each.value.gw.idle_timeout_in_minutes
# }
# resource "azurerm_nat_gateway_public_ip_association" "nat_gateways" {
#   for_each = local.nat_gateways

#   nat_gateway_id       = azurerm_nat_gateway.nat_gateways[each.key].id
#   public_ip_address_id = azurerm_public_ip.nat_gateways[each.value.network_name].id
# }
# resource "azurerm_subnet_nat_gateway_association" "nat_gateways" {
#   for_each = {
#     for k, v in local.subnets : k => v if v.enable_nat_gateway
#   }

#   subnet_id      = data.azurerm_subnet.networks[each.key].id
#   nat_gateway_id = azurerm_nat_gateway.nat_gateways[each.value.network].id
# }