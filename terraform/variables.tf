variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "profilepic-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "app_name" {
  description = "Base name for the application (will be suffixed with random string for uniqueness)"
  type        = string
  default     = "profilepicapp"
}

variable "app_service_sku" {
  description = "SKU for App Service Plan (F1=Free, B1=Basic, S1=Standard, P1V2=Premium)"
  type        = string
  default     = "B1"
  
  validation {
    condition     = contains(["F1", "B1", "B2", "B3", "S1", "S2", "S3", "P1V2", "P2V2", "P3V2"], var.app_service_sku)
    error_message = "app_service_sku must be a valid App Service SKU"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

# Flask Configuration
variable "flask_secret_key" {
  description = "Flask secret key for session encryption"
  type        = string
  sensitive   = true
}

# Azure AD / Entra ID Configuration
variable "client_id" {
  description = "Azure AD Application (client) ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Azure AD client secret value"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD Directory (tenant) ID"
  type        = string
  sensitive   = true
}

# Optional Features
variable "enable_application_insights" {
  description = "Enable Application Insights for monitoring"
  type        = bool
  default     = true
}

variable "enable_staging_slot" {
  description = "Enable staging deployment slot"
  type        = bool
  default     = false
}

variable "allowed_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = []
}

# Classifier API Configuration
variable "enable_classifier_api" {
  description = "Enable separate App Service for Classifier API"
  type        = bool
  default     = false
}

variable "classifier_api_sku" {
  description = "SKU for Classifier API App Service Plan (B1+ recommended for TensorFlow)"
  type        = string
  default     = "B1"
  
  validation {
    condition     = contains(["B1", "B2", "B3", "S1", "S2", "S3", "P1V2", "P2V2", "P3V2"], var.classifier_api_sku)
    error_message = "classifier_api_sku must be B1 or higher (TensorFlow requires more resources)"
  }
}

variable "classifier_allowed_origins" {
  description = "Additional CORS origins for Classifier API (main app is automatically included)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    Application = "ProfilePicApp"
  }
}
