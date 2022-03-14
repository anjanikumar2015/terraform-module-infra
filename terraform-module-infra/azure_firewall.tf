locals {
  firewall = {
    for k, v in try(local.firewalls, {}) : k => merge(
      {
        existing                                = false
        rg                                      = v.rg
        policy_name                             = "baseline"
      },
      v,
      try(v.existing, false) == true ? {} : {
        subnet_id                               = data.azurerm_subnet.subnets["AzureFirewallSubnet"].id
        nic_name                                = "${k}-fw-pip"
        ip_config_name                          = "${k}-AzureFirewallSubnet"
        allocation_method                       = "Static"
        sku                                     = "Standard"
      }
    )
  }
}
resource "azurerm_public_ip" "firewalls" {
  for_each = {
    for k, v in local.firewall : k => v if !v.existing
  }
  name                = each.value.nic_name
  location            = var.inputs.location
  resource_group_name = each.value.rg
  allocation_method   = each.value.allocation_method
  sku                 = each.value.sku
  tags                = local.tags
}
resource "azurerm_firewall_policy" "firewalls" {
  for_each = {
    for policy in local.firewall : policy.policy_name => policy if !policy.existing
  }
  name                = each.value.policy_name
  resource_group_name = each.value.rg
  location            = var.inputs.location
}
resource "azurerm_firewall" "firewalls" {
  for_each = {
    for k, v in local.firewall : k => v if !v.existing
  }
  name                = each.key
  location            = var.inputs.location
  resource_group_name = each.value.rg
  firewall_policy_id  = azurerm_firewall_policy.firewalls[each.value.policy_name].id
  tags                = local.tags
  ip_configuration {
    name                 = each.value.ip_config_name
    subnet_id            = each.value.subnet_id
    public_ip_address_id = azurerm_public_ip.firewalls[each.key].id
  }
  depends_on = [
      azurerm_subnet.subnets
    ]
}
# resource "azurerm_firewall_policy_rule_collection_group" "firewalls" {
#   name               = "example-fwpolicy-rcg"
#   firewall_policy_id = azurerm_firewall_policy.example.id
#   priority           = 500
#   application_rule_collection {
#     name     = "app_rule_collection1"
#     priority = 500
#     action   = "Deny"
#     rule {
#       name = "app_rule_collection1_rule1"
#       protocols {
#         type = "Http"
#         port = 80
#       }
#       protocols {
#         type = "Https"
#         port = 443
#       }
#       source_addresses  = ["10.0.0.1"]
#       destination_fqdns = [".microsoft.com"]
#     }
#   }

#   network_rule_collection {
#     name     = "network_rule_collection1"
#     priority = 400
#     action   = "Deny"
#     rule {
#       name                  = "network_rule_collection1_rule1"
#       protocols             = ["TCP", "UDP"]
#       source_addresses      = ["10.0.0.1"]
#       destination_addresses = ["192.168.1.1", "192.168.1.2"]
#       destination_ports     = ["80", "1000-2000"]
#     }
#   }

#   nat_rule_collection {
#     name     = "nat_rule_collection1"
#     priority = 300
#     action   = "Dnat"
#     rule {
#       name                = "nat_rule_collection1_rule1"
#       protocols           = ["TCP", "UDP"]
#       source_addresses    = ["10.0.0.1", "10.0.0.2"]
#       destination_address = "192.168.1.1"
#       destination_ports   = ["80", "1000-2000"]
#       translated_address  = "192.168.0.1"
#       translated_port     = "8080"
#     }
#   }
# }