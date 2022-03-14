 locals {
  subnets = flatten([
    for vnet_k, vnet_data in try(local.vnets, {}) : [
      for subnet_k, subnet_data in try(vnet_data.subnets, {}) : merge(
        subnet_data,
        {
          network                               = vnet_k
          subnet                                = subnet_k
          delegations                           = try(subnet_data.delegations, [])
          service_endpoints                     = try(subnet_data.service_endpoints, ["Microsoft.KeyVault","Microsoft.Storage"])
          private_endpoint                      = try(subnet_data.private_endpoint, false)
        },
        vnet_data,
        {
          #security_group       = try(azurerm_network_security_group.network_security_groups[subnet_v.security_group].id, null)
          virtual_network_name                  = vnet_k
        }
      )
    ]
  ])
  route = {
    for k, v in try(local.routes, {}) : k => merge(
      v,
      {
        disable_bgp_route_propagation           = false
        routes = {
          for route_key, route_data in try(v.routes, []) : route_key => merge(
            {
              next_hop_type                     = try(v.next_hop_type, "VirtualNetworkGateway")
              next_hop_in_ip_address            = null
            },
            route_data
          )
        }
      }
    )
  }
  route_association = {
    for entry in flatten([
      for k, v in local.routes : [
        for association in try(v.associations, []) : [
          for subnet in try(association.subnets) : {
            key                                 = "${association.network}-${subnet}"
            subnet_id                           = data.azurerm_subnet.subnets[subnet].id
            route_table_id                      = azurerm_route_table.routes[k].id
          }
        ]
      ]
    ]) : entry.key => entry
  }
  peers = flatten([
    for network_key, network_data in try(local.vnets, {}) : [
      for peer_key, peer_data in try(network_data.peers, {}) :  merge(
        peer_data,
        {
          peer                                  = peer_key
          allow_virtual_network_access          = try(peer_data.allow_virtual_network_access,true)
          allow_forwarded_traffic               = try(peer_data.allow_forwarded_traffic,false)
          allow_gateway_transit                 = try(peer_data.allow_gateway_transit,false)
          remote_vnet                           = peer_data.remote_peer.vnet
          remote_rg                             = peer_data.remote_peer.rg
          remote_name                           = "${peer_data.remote_peer.vnet}-TO-${lower(network_key)}"
        },
        network_data,
        {
          name                                  = "${network_key}-TO-${lower(peer_data.remote_peer.vnet)}"
          virtual_network_name                  = network_key
        }
      )
    ]
  ])
  nsg = {
    for k, v in try(local.nsgs, {}) : k => merge(
      {
        diagnostics         = try(v.diagnostics, {})
        tags = merge(
          local.tags,
          try(v.tags, {})
        )
      },
      v,
      {
        rules = [
          for rule in concat(var.nsg_rules, try(v.rules, [])) : merge(
            {
              source_port_range                       = null
              source_port_ranges                      = null
              destination_port_range                  = null
              destination_port_ranges                 = null
              source_address_prefix                   = null
              source_address_prefixes                 = null
              destination_address_prefix              = null
              destination_address_prefixes            = null
              destination_application_security_groups = null
              source_application_security_groups      = null
              description                             = null
            },
            rule
          )
        ]
      }
    )
  }
  nsg_associations = flatten([
    for k, v in local.nsg : [
      for entry in v.associations : [
        for subnet in entry.subnets : {
          subnet                              = subnet
          nsg                                 = k
          key                                 = "${k}-${entry.network}-${subnet}"
        }
      ]
    ]
  ])
  vng = {
    for vng_key, vng_data in try(local.vngs, {}) : vng_key => merge(
      {
        rg                                = vng_data.rg
        sku                               = try(vng_data.sku, "Basic")
        type                              = try(vng_data.type, "Vpn")
        vpn_type                          = try(vng_data.vpn_type, "RouteBased")
        active_active                     = try(vng_data.active_active, false)
        enable_bgp                        = try(vng_data.enable_bgp, false)
        generation                        = try(vng_data.generation, "Generation1")
        p2p                               = try(vng_data.p2p, false)
        pub_ip                            = vng_data.pub_ip
      },
      vng_data,
      {
        tags = merge(
          local.tags,
          try(vng_data.tags, {})
        )
        subnet_id = data.azurerm_subnet.subnets["GatewaySubnet"].id
        ip_config = {
          name                            = "default"
          private_ip_address_allocation   = "Dynamic"
        }
        vpn_client_configuration = {
          vpn_client_protocols            = ["SSTP", "IkeV2"]
          address_space                   = try(vng_data.client_address_prefix, null)
        }
        root_certificate = {
          root_certificate_name           = try(vng_data.root_cert_name, "RootCert")
          root_certificate_data           = try(vng_data.public_cert_data, null)
        }
      }
    )
  }
  bastion = {
    for k, v in try(local.inputs.bastion, {}) : k => merge(
      {
        sku                                       = "Basic"
        pub_ip                                    = v.pub_ip
      },
      v,
      {
        tags = merge(
          local.tags,
          try(v.tags, {})
        )
      }
    )
  }
  pub_ips = {
    for k, v in try(local.inputs.public_ips, {}) : k => merge(
      {
        sku                                       = try(v.sku, "Standard")
        allocation_method                         = try(v.allocation_method, "Static")
      },
      v,
      {
        tags = merge(
          local.tags,
          try(v.tags, {})
        )
      }
    )
  }
  express_route = {
    for k, v in try(local.inputs.express_routes, {}) : k => merge(
      {
        bandwidth_mbps                          = try(v.bandwidth_mbps, 50)
      },
      v,
      {
        sku = {
            tier                                  = try(v.tier, "Standard")
            family                                = try(v.family, "MeteredData")
        }
      },
      {
        tags = merge(
          local.tags,
          try(v.tags, {})
        )
      }
    )
  }
}
resource "azurerm_public_ip" "pub_ips" {
  for_each = local.pub_ips
	name                                            = each.key
	location                                        = var.inputs.location
	resource_group_name                             = each.value.rg
	allocation_method                               = each.value.allocation_method
	sku                                             = each.value.sku
  tags                                            = each.value.tags
  depends_on = [
    azurerm_resource_group.rgs
  ] 
}
resource "azurerm_virtual_network" "vnets" {
    for_each = {
        for k, v in local.vnets : k => v
    }
    name                                      = each.key
    location                                  = var.inputs.location
    resource_group_name                       = each.value.rg
    address_space                             = each.value.address_space
    dns_servers                               = try(each.value.dns, null)
    tags                                      = local.tags

    depends_on = [
      azurerm_resource_group.rgs
    ]
}
resource "azurerm_subnet" "subnets" {
  for_each = {
    for subnet in local.subnets : subnet.subnet => subnet
  }
    resource_group_name                       = each.value.rg
    virtual_network_name                      = each.value.virtual_network_name
    name                                      = each.value.subnet
    address_prefixes                          = each.value.prefix
    service_endpoints                         = each.value.service_endpoints
    enforce_private_link_endpoint_network_policies = each.value.private_endpoint
    dynamic "delegation" {
      for_each = each.value.delegations
      content {
        name                                  = delegation.value.name
      service_delegation {
        actions                               = delegation.value.service_delegation.actions
        name                                  = delegation.value.service_delegation.name
      }
    }
  }
  depends_on = [
    azurerm_virtual_network.vnets
  ]
}
resource "azurerm_route_table" "routes" {
  for_each = local.route

  name                                          = each.key
  location                                      = var.inputs.location
  resource_group_name                           = each.value.rg
  disable_bgp_route_propagation                 = each.value.disable_bgp_route_propagation
  dynamic "route" {
    for_each = each.value.routes
    content {
      name                                      = route.key
      address_prefix                            = route.value.address_prefix
      next_hop_type                             = route.value.next_hop_type
      next_hop_in_ip_address                    = route.value.next_hop_in_ip_address
    }
  }
  tags                                          = local.tags
  depends_on = [
    azurerm_virtual_network.vnets
  ]
}
resource "azurerm_subnet_route_table_association" "route_tables" {
  for_each = local.route_association

  subnet_id                                     = each.value.subnet_id
  route_table_id                                = each.value.route_table_id
}
resource "azurerm_virtual_network_peering" "local" {
  for_each = {
    for peer in local.peers : peer.name => peer if peer.local_peer.remote == false
  }

  name                                = each.value.name
  resource_group_name                 = each.value.rg
  virtual_network_name                = each.value.virtual_network_name
  remote_virtual_network_id           = try(data.azurerm_virtual_network.vnet_remote[each.value.name].id, data.azurerm_virtual_network.vnets[each.value.virtual_network_name].id)
  allow_virtual_network_access        = each.value.allow_virtual_network_access
  allow_forwarded_traffic             = each.value.allow_forwarded_traffic
  allow_gateway_transit               = each.value.allow_gateway_transit

  depends_on = [
    azurerm_subnet.subnets
  ]
}
resource "azurerm_virtual_network_peering" "remote" {
  for_each = {
    for peer in local.peers : peer.name => peer if peer.remote_peer.remote == true
  }

  provider                            = azurerm.remote
  name                                = each.value.remote_name
  resource_group_name                 = each.value.remote_rg
  virtual_network_name                = each.value.remote_vnet
  remote_virtual_network_id           = data.azurerm_virtual_network.vnets[each.value.virtual_network_name].id
  allow_virtual_network_access        = each.value.allow_virtual_network_access
  allow_forwarded_traffic             = each.value.allow_forwarded_traffic
  allow_gateway_transit               = each.value.allow_gateway_transit

  depends_on = [
    azurerm_subnet.subnets
  ]
}
resource "azurerm_network_security_group" "nsgs" {
  for_each = local.nsg

  name                                          = each.key
  location                                      = var.inputs.location
  resource_group_name                           = each.value.rg
  tags                                          = local.tags

  depends_on = [
    azurerm_resource_group.rgs
  ]
}
resource "azurerm_subnet_network_security_group_association" "nsgs" {
  for_each = {
    for entry in local.nsg_associations : entry.key => entry
  }

  subnet_id                                     = data.azurerm_subnet.subnets[each.value.subnet].id
  network_security_group_id                     = azurerm_network_security_group.nsgs[each.value.nsg].id

  depends_on = [
    azurerm_subnet.subnets
  ]
  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
resource "azurerm_virtual_network_gateway" "vng" {
  for_each = local.vng
  name                            = each.key
  location                        = var.inputs.location
  resource_group_name             = each.value.rg
  type                            = each.value.type
  vpn_type                        = each.value.vpn_type
  active_active                   = each.value.active_active
  enable_bgp                      = each.value.enable_bgp
  sku                             = each.value.sku
  generation                      = each.value.generation
  ip_configuration {
    name                          = each.value.ip_config.name
    public_ip_address_id          = azurerm_public_ip.pub_ips[each.value.pub_ip].id
    private_ip_address_allocation = each.value.ip_config.private_ip_address_allocation
    subnet_id                     = each.value.subnet_id
  }
  # vpn_client_configuration {
  #   address_space                 = each.value.vpn_client_configuration.address_space
  #   vpn_client_protocols          = each.value.vpn_client_configuration.vpn_client_protocols
  #   root_certificate {
  #     name                        = each.value.root_certificate.root_certificate_name
  #     public_cert_data            = each.value.root_certificate.root_certificate_data
  #   }
  # }
  lifecycle {
    ignore_changes = [
      ip_configuration
    ]
  }
}
resource "azurerm_bastion_host" "bastion" {
  for_each = local.bastion
  name                            = each.key
  location                        = var.inputs.location
  resource_group_name             = each.value.rg
  ip_configuration {
    name                          = "default"
    subnet_id                     = data.azurerm_subnet.subnets["AzureBastionSubnet"].id
    public_ip_address_id          = azurerm_public_ip.pub_ips[each.value.pub_ip].id
  }
  lifecycle {
    ignore_changes = [
      ip_configuration
    ]
  }
}
resource "azurerm_express_route_circuit" "express_route" {
  for_each = {
      for k, v in local.express_route : k => v
  }
  name                        = each.key
  resource_group_name         = each.value.rg
  location                    = var.inputs.location
  service_provider_name       = each.value.provider
  peering_location            = each.value.peering_location
  bandwidth_in_mbps           = try(each.value.bandwidth_mbps)
  sku {
    tier   = each.value.sku.tier
    family = each.value.sku.family
  }
  tags = each.value.tags
}