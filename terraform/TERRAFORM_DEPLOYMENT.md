# Terraform Deployment Guide

This guide walks you through deploying the Profile Picture App infrastructure to Azure using Terraform.

## Prerequisites

- Azure CLI installed and configured (`az --version` should work)
- Terraform installed (download from [terraform.io](https://www.terraform.io/downloads))
- Azure subscription with appropriate permissions
- App already working locally (completed AZURE_SETUP_GUIDE.md)

## Quick Start

```powershell
# 1. Install Terraform (if not already installed)
winget install HashiCorp.Terraform

# 2. Verify Terraform installation
terraform --version

# 3. Login to Azure
az login

# 4. Get your subscription ID
az account show --query id --output tsv

# 5. Navigate to terraform directory
cd terraform

# 6. Create your terraform.tfvars file
Copy-Item terraform.tfvars.example terraform.tfvars

# 7. Edit terraform.tfvars with your values
code terraform.tfvars

# 8. Initialize Terraform
terraform init

# 9. Preview the changes
terraform plan

# 10. Deploy the infrastructure
terraform apply

# 11. Update Azure AD redirect URI with the output
```

---

## Detailed Setup Instructions

### Step 1: Install Terraform

#### Option A: Using winget (Recommended)
```powershell
winget install HashiCorp.Terraform
```

#### Option B: Using Chocolatey
```powershell
choco install terraform
```

#### Option C: Manual Download
1. Go to [terraform.io/downloads](https://www.terraform.io/downloads)
2. Download the Windows 64-bit version
3. Extract the `terraform.exe` to a directory
4. Add the directory to your PATH

#### Verify Installation
```powershell
terraform --version
# Should show: Terraform v1.x.x
```

---

### Step 2: Get Your Azure Subscription ID

```powershell
# Login to Azure if not already logged in
az login

# Get your subscription ID
az account show --query id --output tsv

# If you have multiple subscriptions, list them
az account list --output table

# Set the subscription you want to use
az account set --subscription "your-subscription-id"
```

Copy the subscription ID - you'll need it for the next step.

---

### Step 3: Configure Terraform Variables

1. **Navigate to the terraform directory:**
   ```powershell
   cd c:\Users\lobra\Documents\Repos\profilepicapp\terraform
   ```

2. **Create your variables file:**
   ```powershell
   Copy-Item terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`:**
   ```powershell
   code terraform.tfvars
   ```

4. **Fill in your values:**

   ```hcl
   # Azure Configuration
   subscription_id      = "paste-your-subscription-id-here"
   resource_group_name  = "profilepic-rg"
   location            = "East US"  # Change if you prefer another region
   app_name            = "profilepicapp"
   
   # App Service Configuration
   app_service_sku = "B1"  # B1 recommended for production, F1 for free tier
   environment     = "production"
   
   # Flask Configuration (use same value from your .env file)
   flask_secret_key = "paste-your-flask-secret-key-here"
   
   # Azure AD / Entra ID Configuration (use same values from your .env file)
   client_id     = "paste-your-application-client-id-here"
   client_secret = "paste-your-client-secret-value-here"
   tenant_id     = "paste-your-directory-tenant-id-here"
   
   # Optional Features
   enable_application_insights = true   # Recommended for monitoring
   enable_staging_slot        = false   # Set to true if you want a staging environment
   
   # Tags
   tags = {
     Environment = "Production"
     ManagedBy   = "Terraform"
     Application = "ProfilePicApp"
     Owner       = "Your Name"
   }
   ```

5. **Save the file** (Ctrl + S)

**Important:** The `terraform.tfvars` file contains secrets and should NOT be committed to Git. It's already in `.gitignore`.

---

### Step 4: Initialize Terraform

This downloads the required provider plugins (Azure, Random).

```powershell
# Make sure you're in the terraform directory
cd c:\Users\lobra\Documents\Repos\profilepicapp\terraform

# Initialize Terraform
terraform init
```

You should see:
```
Initializing the backend...
Initializing provider plugins...
...
Terraform has been successfully initialized!
```

---

### Step 5: Preview the Infrastructure

Before creating anything, preview what Terraform will create:

```powershell
terraform plan
```

This will show you:
- Resource Group
- App Service Plan
- Linux Web App
- Application Insights (if enabled)
- Log Analytics Workspace (if enabled)

Review the output to ensure everything looks correct.

---

### Step 6: Deploy the Infrastructure

```powershell
terraform apply
```

Terraform will:
1. Show you the plan again
2. Ask for confirmation: Type `yes` and press Enter
3. Create all the Azure resources (takes 2-5 minutes)

**Save the outputs!** After deployment, Terraform will display important information:

```
Outputs:

app_service_name = "profilepicapp-abc123"
app_service_url = "https://profilepicapp-abc123.azurewebsites.net"
redirect_uri = "https://profilepicapp-abc123.azurewebsites.net/auth/callback"
deployment_commands = <<EOT
...deployment instructions...
EOT
```

---

### Step 7: Update Azure AD Redirect URI

**Critical:** You need to add the production redirect URI to your Azure AD app registration.

1. **Copy the `redirect_uri` from Terraform output**
   - Example: `https://profilepicapp-abc123.azurewebsites.net/auth/callback`

2. **Go to Azure Portal:**
   - Navigate to **Microsoft Entra ID** → **App registrations**
   - Click on your **ProfilePicApp**
   - Click **Authentication** in the left sidebar
   - Under **Platform configurations** → **Web** → **Redirect URIs**
   - Click **Add URI**
   - Paste the production redirect URI
   - Click **Save**

3. **You should now have two redirect URIs:**
   - `http://localhost:5000/auth/callback` (for local development)
   - `https://profilepicapp-abc123.azurewebsites.net/auth/callback` (for production)

---

### Step 8: Deploy Your Application Code

Now that the infrastructure exists, deploy your code:

#### Option A: Using Azure CLI (Recommended)

```powershell
# Navigate to your project root
cd c:\Users\lobra\Documents\Repos\profilepicapp

# Make sure you have a startup command file
# (Terraform already configured the app settings)

# Deploy the code
az webapp up --name profilepicapp-abc123 --resource-group profilepic-rg --runtime "PYTHON:3.13"
```

Replace `profilepicapp-abc123` with your actual app name from Terraform output.

#### Option B: Using Git Deployment

```powershell
# Get the deployment URL from Terraform output or run:
$appName = terraform output -raw app_service_name

# Configure Git deployment
az webapp deployment source config-local-git --name $appName --resource-group profilepic-rg

# Add Azure as a remote
git remote add azure https://$appName.scm.azurewebsites.net:443/$appName.git

# Deploy
git push azure main:master
```

#### Option C: Using VS Code Extension

1. Install "Azure App Service" extension in VS Code
2. Click Azure icon in sidebar
3. Right-click your app service
4. Select "Deploy to Web App"
5. Choose your project folder

---

### Step 9: Test Your Production App

1. **Get your app URL from Terraform output:**
   ```powershell
   terraform output app_service_url
   ```

2. **Open the URL in your browser**

3. **Click "Sign in with Microsoft"**

4. **Verify your profile and picture load**

---

## Infrastructure Details

### What Terraform Creates

- **Resource Group**: Container for all resources
- **App Service Plan**: Compute resources (B1 SKU = 1 core, 1.75GB RAM)
- **Linux Web App**: Your Flask application
- **Application Insights**: Monitoring and diagnostics (optional)
- **Log Analytics Workspace**: Log storage for App Insights (optional)

### App Service SKU Options

| SKU | Type | Price | Use Case |
|-----|------|-------|----------|
| F1 | Free | $0/month | Development/Testing only |
| B1 | Basic | ~$13/month | Small production apps |
| B2 | Basic | ~$26/month | Medium workloads |
| S1 | Standard | ~$70/month | Production with auto-scale |
| P1V2 | Premium | ~$146/month | High-performance production |

### Estimated Costs

**Minimum Configuration (B1 + App Insights):**
- App Service Plan B1: ~$13/month
- Application Insights: ~$2.30/GB ingested (first 5GB free)
- **Total: ~$13-15/month**

**Free Tier (F1):**
- Cost: $0
- Limitations: 60 CPU minutes/day, no custom domains, no auto-scale

---

## Managing Your Infrastructure

### View Current State

```powershell
terraform show
```

### Update Configuration

1. Edit `terraform.tfvars` or the `.tf` files
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

### Destroy Infrastructure

**Warning:** This deletes all resources and data!

```powershell
terraform destroy
```

Type `yes` to confirm.

---

## Common Terraform Commands

```powershell
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Preview changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources
terraform state list

# Get specific output
terraform output app_service_url

# Destroy all resources
terraform destroy

# Re-create a specific resource
terraform taint azurerm_linux_web_app.main
terraform apply
```

---

## Troubleshooting

### "Error: Subscription not found"
- Run `az login` again
- Verify subscription ID: `az account show --query id`
- Set correct subscription: `az account set --subscription "id"`

### "Error: authorization failed"
- Your account needs Contributor role on the subscription
- Contact your Azure administrator

### "Error: Name already exists"
- The app name must be globally unique
- Change `app_name` in `terraform.tfvars`
- Run `terraform apply` again

### "App deployed but shows error"
- Check app logs: `az webapp log tail --name app-name --resource-group profilepic-rg`
- Verify environment variables in Azure Portal
- Check that `requirements.txt` is included in deployment

### "Authentication fails in production"
- Verify redirect URI is added in Azure AD app registration
- Check that it matches exactly: `https://your-app.azurewebsites.net/auth/callback`
- No trailing slashes, correct protocol (https)

---

## Security Best Practices

✅ **Never commit `terraform.tfvars` to Git**
✅ **Use different secrets for dev and production**
✅ **Enable Application Insights for monitoring**
✅ **Regularly rotate client secrets**
✅ **Use Azure Key Vault for production secrets** (advanced)
✅ **Enable HTTPS only** (already configured)

---

## Next Steps

- **Set up CI/CD** with GitHub Actions or Azure DevOps
- **Configure custom domain** and SSL certificate
- **Enable staging slots** for zero-downtime deployments
- **Set up alerts** in Application Insights
- **Implement backup strategy**

---

## Additional Resources

- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure App Service Docs](https://docs.microsoft.com/azure/app-service/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

---

Need help? Check the main README.md or AZURE_SETUP_GUIDE.md
