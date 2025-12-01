output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.main.name
}

output "app_service_url" {
  description = "URL of the deployed application"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "app_service_hostname" {
  description = "Default hostname of the App Service"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "redirect_uri" {
  description = "Redirect URI to add to Azure AD app registration"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}/auth/callback"
}

output "staging_url" {
  description = "URL of the staging slot (if enabled)"
  value       = var.enable_staging_slot ? "https://${azurerm_linux_web_app.main.name}-staging.azurewebsites.net" : "Staging slot not enabled"
}

# Classifier API Outputs
output "classifier_api_name" {
  description = "Name of the Classifier API App Service"
  value       = var.enable_classifier_api ? azurerm_linux_web_app.classifier[0].name : "Classifier API not enabled"
}

output "classifier_api_url" {
  description = "URL of the Classifier API"
  value       = var.enable_classifier_api ? "https://${azurerm_linux_web_app.classifier[0].default_hostname}" : "Classifier API not enabled"
}

output "classifier_api_hostname" {
  description = "Default hostname of the Classifier API"
  value       = var.enable_classifier_api ? azurerm_linux_web_app.classifier[0].default_hostname : "Classifier API not enabled"
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].instrumentation_key : "Application Insights not enabled"
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].connection_string : "Application Insights not enabled"
  sensitive   = true
}

output "deployment_commands" {
  description = "Commands to deploy your application"
  value = <<-EOT
    # Deploy Main App using Azure CLI:
    az webapp up --name ${azurerm_linux_web_app.main.name} --resource-group ${azurerm_resource_group.main.name} --runtime "PYTHON:3.13"
    
    ${var.enable_classifier_api ? "# Deploy Classifier API:\n    az webapp deployment source config-zip --name ${azurerm_linux_web_app.classifier[0].name} --resource-group ${azurerm_resource_group.main.name} --src classifier-deploy.zip" : ""}
    
    # Or deploy using Git:
    git remote add azure https://${azurerm_linux_web_app.main.name}.scm.azurewebsites.net:443/${azurerm_linux_web_app.main.name}.git
    git push azure main:master
    
    # Or deploy using VS Code Azure App Service extension
  EOT
}
