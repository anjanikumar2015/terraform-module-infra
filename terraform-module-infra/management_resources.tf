locals {
  storage = {
    for storage_key, storage_data in try(local.mgmt.storage, {}) : storage_key => merge(
        storage_data,
        {
            existing                                = try(storage_data.existing, false)
            remote                                  = try(storage_data.remote, false)
            account_tier                            = try(storage_data.tier, "Standard")
            account_kind                            = try(storage_data.kind, "StorageV2")
            account_replication_type                = try(storage_data.replication_type, "LRS")
            min_tls_version                         = try(storage_data.tls_version, "TLS1_2")
            enable_https_traffic_only               = true
            is_hns_enabled                          = false
            private_endpoint                        = try(storage_data.private_endpoint, false)
            storage                                 = storage_key
            default_action                          = try(storage_data.default_action, "Deny")
            pe_subnet                               = try(storage_data.pe_subnet, null)
            tags = merge(
                local.tags,
                try(storage_data.tags, {})
            )
        },
    )
  }
  container = flatten([
      for storage_key, storage_data in try(local.mgmt.storage, {}) : [
          for container_key, container_data in try(storage_data.containers, {}) : merge(
              container_data,
              {
                name                                = container_key
                access_type                         = try(container_data.access_type, "private")
              },
              storage_data,
              {
                  storage                           = storage_key
              }
          )
      ]
  ])
  loganalytic = {
    for la_key, la_data in try(local.mgmt.loganalytics, {}) : la_key => merge(
        {
            existing                                = try(la_data.existing, false)
            remote                                  = try(la_data.remote, false)
            name                                    = la_key
            retention_in_days                       = 30
            solutions                               = []
        },
        la_data,
        {
            sku                                     = "PerGB2018"
            tags = merge(
                local.tags,
                try(la_data.tags, {})
            )
        }
    )
  }
  la_solution = flatten([
      for la_key, la_data in try(local.mgmt.loganalytics, {}) : [
          for solution in try(la_data.solutions, {}) : merge(
              solution,
              la_data,
              {
                  workspace                     = la_key
              }
          )
      ]
  ])
  rsv = {
    for rsv_key, rsv_data in try(local.mgmt.rsv, {}) : rsv_key => merge(
      {
        name                                    = rsv_key
        sku                                     = try(rsv_data.sku, "Standard")
        soft_delete_enabled                     = try(rsv_data.soft_delete_enabled, false)
        private_endpoint                        = try(rsv_data.private_endpoint, false)
        backup                                  = try(rsv_data.backup, true)
        storage_mode_type                       = try(rsv_data.storage_mode_type, "LocallyRedundant")
      },
      rsv_data,
      {
        tags = merge(
            local.tags,
            try(rsv_data.tags, {})
        )
      }
    )
  }
  policy = flatten([
      for rsv_key, rsv_data in try(local.mgmt.rsv, {}) : [
        for policy_key, policy_data in try(rsv_data.policies, {}) : merge(
          policy_data,
          {
            name                              = policy_key
            backup_frequency                  = try(policy_data.backup_frequency, "Daily")
            backup_time                       = try(policy_data.backup_time, "23:00")
            timezone                          = "UTC"
            retention_daily                   = try(policy_data.retention_daily, null)
            retention_weekly                  = null
            retention_monthly                 = null
            retention_yearly                  = null
          },
          rsv_data,
          {
            vault_name                        = rsv_key
          }
        )
      ]
    ])
  kv = {
    for kv_key, kv_data in try(var.inputs.mgmt.keyvault, {}) : kv_key => merge(
      {
        name                                   = kv_key
        sku                                    = "standard"
        purge_protection_enabled               = try(kv_data.purge_protection_enabled, false)
        soft_delete_retention_days             = try(kv_data.soft_delete_retention_days, 7)
        pe_subnet                               = try(kv_data.pe_subnet, null)
        private_endpoint                        = try(kv_data.private_endpoint, false)
        default_action                          = try(kv_data.default_action, "Deny")
        bypass                                  = try(kv_data.bypass, "AzureServices")
      },
      kv_data,
      {
        tags = merge(
            local.tags,
            try(kv_data.tags, {})
        )
      }
    )
  }
  mg = {
    for k, v in try(var.inputs.management_group, {}) : k => merge(
        {
            existing                            = false
        },
        v,
        {
            subscriptions                      = try(var.inputs.management_group.subscriptions, [], null)
        }
    )
  }
}
resource "azurerm_management_group" "mg" {
    for_each = {
        for k, v in local.mg : k => v if !v.existing
    }
    display_name                                  = each.key
    subscription_ids = [
        data.azurerm_subscription.primary.subscription_id,
    ]
}
resource "azurerm_storage_account" "storage" {
    for_each = {
        for k, v in local.storage : k => v if !v.existing
    }
    name                                          = each.key
    location                                      = var.inputs.location
    resource_group_name                           = each.value.rg
    account_tier                                  = each.value.account_tier
    account_kind                                  = each.value.account_kind
    account_replication_type                      = each.value.account_replication_type
    enable_https_traffic_only                     = each.value.enable_https_traffic_only
    is_hns_enabled                                = each.value.is_hns_enabled
    min_tls_version                               = each.value.min_tls_version
    network_rules {
        default_action                            = each.value.default_action
    }
    depends_on = [
        azurerm_resource_group.rgs
    ]
    tags                                          = each.value.tags
}
resource "azurerm_storage_container" "storage" {
    for_each = {
      for container in try(local.container, {}) : container.name => container
    }

    name                                        = each.key
    storage_account_name                        = azurerm_storage_account.storage[each.value.storage].name
    container_access_type                       = each.value.access_type
}
resource "azurerm_log_analytics_workspace" "loganalytics" {
    for_each = {
        for la in try(local.loganalytic, {}) : la.name => la if !la.existing
    }
    name                                          = each.key
    location                                      = var.inputs.location
    resource_group_name                           = each.value.rg
    sku                                           = each.value.sku
    retention_in_days                             = each.value.retention_in_days
    depends_on = [
        azurerm_resource_group.rgs
    ]
    tags                                          = each.value.tags
}
resource "azurerm_log_analytics_solution" "loganalytics" {
    for_each = {
        for solution in try(local.la_solution, {}) : solution.name => solution
    }
    solution_name                                 = each.value.name
    location                                      = var.inputs.location
    resource_group_name                           = each.value.rg
    workspace_resource_id                         = try(azurerm_log_analytics_workspace.loganalytics[each.value.workspace].id, data.azurerm_log_analytics_workspace.loganalytics[each.value.workspace])
    workspace_name                                = each.value.workspace
    plan {
        publisher                                 = each.value.publisher
        product                                   = each.value.product
    }
    tags                                          = local.tags
}
resource "azurerm_recovery_services_vault" "rsv" {
    for_each = {
        for rsv in try(local.rsv, {}) : rsv.name => rsv
    }
    name                                          = each.key
    location                                      = var.inputs.location
    resource_group_name                           = each.value.rg
    sku                                           = each.value.sku
    soft_delete_enabled                           = each.value.soft_delete_enabled
    storage_mode_type                             = each.value.storage_mode_type
    identity {
        type                                      = "SystemAssigned"
    }
    depends_on = [
        azurerm_resource_group.rgs
    ]
    tags                                          = each.value.tags
}
resource "azurerm_backup_policy_vm" "rsv" {
    for_each = {
        for policy in try(local.policy, {}) : policy.name => policy
    }
    name                                            = each.value.name
    resource_group_name                             = each.value.rg
    recovery_vault_name                             = azurerm_recovery_services_vault.rsv[each.value.vault_name].name
    timezone                                        = each.value.timezone
    backup {
        frequency                                   = each.value.backup_frequency
        time                                        = each.value.backup_time
    }
    dynamic "retention_daily" {
        for_each = each.value.retention_daily != null ? [1] : []

        content {
        count = each.value.retention_daily.count
        }
    }
    dynamic "retention_weekly" {
        for_each = each.value.retention_weekly != null ? [1] : []

        content {
        count    = each.value.retention_weekly.count
        weekdays = each.value.retention_weekly.weekdays
        }
    }
    dynamic "retention_monthly" {
        for_each = each.value.retention_monthly != null ? [1] : []

        content {
        count    = each.value.retention_monthly.count
        weekdays = each.value.retention_monthly.weekdays
        weeks    = each.value.retention_monthly.weeks
        }
    }
    dynamic "retention_yearly" {
        for_each = each.value.retention_yearly != null ? [1] : []

        content {
        count    = each.value.retention_yearly.count
        weekdays = each.value.retention_yearly.weekdays
        weeks    = each.value.retention_yearly.weeks
        months   = each.value.retention_yearly.months
        }
    }
    depends_on = [
        azurerm_recovery_services_vault.rsv
    ]
    tags                                          = local.tags
    lifecycle {
        ignore_changes = [
            tags
        ]
    }
}
resource "azurerm_key_vault" "kv" {
    for_each = {
        for kv in try(local.kv, {}) : kv.name => kv
    }
    name                                            = each.key
    location                                        = var.inputs.location
    resource_group_name                             = each.value.rg
    sku_name                                        = each.value.sku
    tenant_id                                       = data.azurerm_client_config.current.tenant_id
    purge_protection_enabled                        = each.value.purge_protection_enabled
    soft_delete_retention_days                      = each.value.soft_delete_retention_days
    network_acls {
        default_action                              = each.value.default_action
        bypass                                      = each.value.bypass
        ip_rules                                    = try(each.value.allowed_ips, null)
    }
    depends_on = [
        azurerm_resource_group.rgs
    ]
    tags                                            = each.value.tags
}
resource "azurerm_key_vault_access_policy" "kv" {
    for_each = local.kv
    key_vault_id                                    = azurerm_key_vault.kv[each.key].id
    tenant_id                                       = data.azurerm_client_config.current.tenant_id
    object_id                                       = data.azurerm_client_config.current.object_id
    key_permissions = [
        "get", "list", "create", "delete", "recover", "purge"
    ]
    secret_permissions = [
        "get", "list", "set", "delete", "recover", "purge"
    ]
}
resource "random_password" "kv" {
  length    = 16
  special   = true
  min_upper = 1
  min_lower = 1
}
resource "azurerm_key_vault_secret" "kv" {
  for_each = {
    for k, v in local.kv : k => v
  }
  name         = var.inputs.os_admin
  value        = random_password.kv.result
  key_vault_id = azurerm_key_vault.kv[each.key].id
  depends_on = [
    azurerm_key_vault_access_policy.kv
  ]
}