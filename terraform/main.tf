terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  # subscription_id will be read from Azure CLI authentication
  # or can be specified via environment variable: ARM_SUBSCRIPTION_ID
}

# Random string for unique naming
resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# App Service Plan (Linux)
resource "azurerm_service_plan" "main" {
  name                = "${var.app_name}-plan-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku

  tags = var.tags
}

# Classifier API App Service Plan (needs higher SKU for TensorFlow)
resource "azurerm_service_plan" "classifier" {
  count               = var.enable_classifier_api ? 1 : 0
  name                = "${var.app_name}-classifier-plan-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.classifier_api_sku

  tags = merge(var.tags, {
    Component = "ClassifierAPI"
  })
}

# App Service (Web App)
resource "azurerm_linux_web_app" "main" {
  name                = "${var.app_name}-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

  site_config {
    always_on = var.app_service_sku != "F1" ? true : false
    
    application_stack {
      python_version = "3.13"
    }

    # CORS settings (optional, for API calls from other domains)
    dynamic "cors" {
      for_each = length(var.allowed_origins) > 0 ? [1] : []
      content {
        allowed_origins = var.allowed_origins
      }
    }
  }

  app_settings = {
    # Flask configuration
    "FLASK_APP"                     = "app.py"
    "FLASK_ENV"                     = var.environment
    "FLASK_SECRET_KEY"              = var.flask_secret_key
    
    # Azure AD / Entra ID configuration
    "CLIENT_ID"                     = var.client_id
    "CLIENT_SECRET"                 = var.client_secret
    "TENANT_ID"                     = var.tenant_id
    "REDIRECT_URI"                  = "https://${var.app_name}-${random_string.unique.result}.azurewebsites.net/auth/callback"
    
    # Python/SCM settings
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "ENABLE_ORYX_BUILD"              = "true"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  tags = var.tags
}

# Classifier API App Service
resource "azurerm_linux_web_app" "classifier" {
  count               = var.enable_classifier_api ? 1 : 0
  name                = "${var.app_name}-classifier-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.classifier[0].id
  https_only          = true

  site_config {
    always_on = true  # Required for B1+ SKU
    
    # IP restrictions - only allow traffic from main app
    ip_restriction_default_action = "Deny"
    
    # Allow outbound IPs from main app
    dynamic "ip_restriction" {
      for_each = toset(split(",", azurerm_linux_web_app.main.outbound_ip_addresses))
      content {
        name       = "Allow-Main-App-${replace(ip_restriction.value, ".", "-")}"
        action     = "Allow"
        ip_address = "${ip_restriction.value}/32"
        priority   = 100
      }
    }
    
    # Allow Azure services (for deployment and management)
    ip_restriction {
      name                      = "Allow-Azure-Services"
      action                    = "Allow"
      service_tag               = "AzureCloud"
      priority                  = 200
    }
    
    application_stack {
      python_version = "3.11"  # TensorFlow 2.18.0 works best with Python 3.9-3.12
    }

    # CORS settings - allow main app and other origins
    cors {
      allowed_origins = concat(
        ["https://${azurerm_linux_web_app.main.default_hostname}"],
        var.classifier_allowed_origins
      )
      support_credentials = false
    }
  }

  app_settings = {
    # Flask configuration
    "FLASK_APP"                     = "classifier_api.py"
    "FLASK_ENV"                     = var.environment
    
    # Python/SCM settings
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "ENABLE_ORYX_BUILD"              = "true"
    
    # Startup command
    "WEBSITES_PORT"                  = "5001"
    
    # Performance settings for ML workloads
    "WEBSITE_TIME_ZONE"              = "UTC"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  tags = merge(var.tags, {
    Component = "ClassifierAPI"
  })
}

# Application Insights (optional but recommended for monitoring)
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "${var.app_name}-logs-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_application_insights" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "${var.app_name}-insights-${random_string.unique.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main[0].id
  application_type    = "web"

  tags = var.tags
}

# Add Application Insights to App Service if enabled
resource "azurerm_linux_web_app_slot" "staging" {
  count          = var.enable_staging_slot ? 1 : 0
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id

  site_config {
    always_on = var.app_service_sku != "F1" ? true : false
    
    application_stack {
      python_version = "3.13"
    }
  }

  app_settings = {
    "FLASK_APP"        = "app.py"
    "FLASK_ENV"        = "staging"
    "FLASK_SECRET_KEY" = var.flask_secret_key
    "CLIENT_ID"        = var.client_id
    "CLIENT_SECRET"    = var.client_secret
    "TENANT_ID"        = var.tenant_id
    "REDIRECT_URI"     = "https://${var.app_name}-${random_string.unique.result}-staging.azurewebsites.net/auth/callback"
  }

  tags = var.tags
}
