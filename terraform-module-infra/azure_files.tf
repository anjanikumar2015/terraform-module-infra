locals {
  files = {
        for file_key, file_data in try(local.azurefiles, {}) : file_key => merge(
            {
                existing                                = false
                account_tier                            = "Premium"
                account_kind                            = "FileStorage"
                account_replication_type                = "ZRS"
                min_tls_version                         = "TLS1_2"
                enable_https_traffic_only               = false
                is_hns_enabled                          = false
            },
            file_data,
        )
    }
  share = flatten([
      for file_key, file_data in try(local.files, {}) : [
          for share_key, share_data in try(file_data.shares, {}) : merge(
              share_data,
              {
                name                                    = share_key
                quota                                   = try(share_data.quota, 100)
                enabled_protocol                        = try(share_data.enabled_protocol, "NFS")
              },
              file_data,
              {
                file                                    = file_key
              }
          )
      ]
  ])
}
resource "azurerm_storage_account" "files" {
    for_each = {
        for k, v in local.files : k => v
    }
    name                                            = each.key
    location                                        = var.inputs.location
    resource_group_name                             = each.value.rg
    account_tier                                    = each.value.account_tier
    account_kind                                    = each.value.account_kind
    account_replication_type                        = each.value.account_replication_type
    enable_https_traffic_only                       = each.value.enable_https_traffic_only
    is_hns_enabled                                  = each.value.is_hns_enabled
    min_tls_version                                 = each.value.min_tls_version
    network_rules {
        default_action                              = "Deny"
    }
    depends_on = [
        azurerm_resource_group.rgs
    ]
    tags                                          = local.tags
}
resource "azurerm_storage_share" "files" {
    for_each = {
        for share in local.share : share.name => share
    }
    name                                              = each.value.name
    storage_account_name                              = azurerm_storage_account.files[each.value.file].name
    quota                                             = each.value.quota
    enabled_protocol                                  = each.value.enabled_protocol
}