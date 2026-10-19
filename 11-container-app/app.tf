locals {
  tags = {
    project    = "azure-terraform-labs"
    lab        = "11"
    managed_by = "terraform"
    owner      = "jeetan"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}-11"
  location = var.location
  tags     = local.tags
}

# Where the logs end up. The first 5 GB per month are free; the daily quota
# stops ingestion at 100 MB per day, so a noisy app can't run up a bill.
resource "azurerm_log_analytics_workspace" "lab" {
  name                = "log-${var.prefix}-11"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.1
  tags                = local.tags
}

# The "building" the container apps live in.
# logs_destination = "azure-monitor": logs go wherever a diagnostic setting
# sends them. The older "log-analytics" destination uses an API whose support
# ended on 14 September 2026 (Microsoft docs).
resource "azurerm_container_app_environment" "lab" {
  name                = "cae-${var.prefix}-11"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  logs_destination    = "azure-monitor"
  tags                = local.tags
}

# Send the environment's logs to the workspace.
resource "azurerm_monitor_diagnostic_setting" "env" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_container_app_environment.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }

  enabled_log {
    category = "ContainerAppHTTPLogs"
  }
}

# The web app itself: one container, reachable from the internet over HTTPS.
resource "azurerm_container_app" "web" {
  name                         = "ca-${var.prefix}-11-web"
  container_app_environment_id = azurerm_container_app_environment.lab.id
  resource_group_name          = azurerm_resource_group.lab.name
  revision_mode                = "Single"
  tags                         = local.tags

  template {
    # Scale to zero when nobody visits: no replicas, no compute charges.
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "web"
      image  = var.image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled           = true
    target_port                = 80
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
