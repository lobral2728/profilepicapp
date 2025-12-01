# Terraform Deployment Guide - Classifier API

## Overview

The Terraform configuration now supports deploying a separate Azure App Service for the Classifier API, creating a proper microservices architecture.

## Architecture

```
┌─────────────────────────────────┐
│  Main Flask App                 │
│  profilepicapp-c2p7wl           │
│  SKU: F1 (Free)                 │
│  Python: 3.13                   │
│  Port: 5000                     │
└────────────┬────────────────────┘
             │
             │ HTTPS
             │
┌────────────▼────────────────────┐
│  Classifier API                 │
│  profilepicapp-classifier-xxxxx │
│  SKU: B1 (Basic)                │
│  Python: 3.11                   │
│  Port: 5001                     │
└─────────────────────────────────┘
```

## Configuration Changes

### New Variables (variables.tf)

```hcl
variable "enable_classifier_api" {
  description = "Enable separate App Service for Classifier API"
  type        = bool
  default     = false
}

variable "classifier_api_sku" {
  description = "SKU for Classifier API (B1+ recommended for TensorFlow)"
  type        = string
  default     = "B1"
}

variable "classifier_allowed_origins" {
  description = "Additional CORS origins for Classifier API"
  type        = list(string)
  default     = []
}
```

### New Resources (main.tf)

1. **App Service Plan for Classifier**
   - Separate plan for independent scaling
   - SKU: B1 or higher (TensorFlow needs more memory)
   - Python: 3.11 (better TensorFlow compatibility)

2. **Classifier API App Service**
   - Dedicated App Service for classifier API
   - CORS automatically configured for main app
   - Runs on port 5001
   - Optimized settings for ML workloads

### New Outputs (outputs.tf)

- `classifier_api_name` - Name of the classifier service
- `classifier_api_url` - Full HTTPS URL
- `classifier_api_hostname` - Hostname for configuration

## Deployment Steps

### 1. Enable Classifier API

Edit `terraform.tfvars`:
```hcl
enable_classifier_api      = true
classifier_api_sku        = "B1"    # or B2, S1, etc.
```

### 2. Review Changes

```powershell
cd terraform
terraform plan
```

Expected changes:
- `+` azurerm_service_plan.classifier[0]
- `+` azurerm_linux_web_app.classifier[0]

### 3. Apply Configuration

```powershell
terraform apply
```

Review the plan and type `yes` to confirm.

### 4. Note the Outputs

```powershell
terraform output classifier_api_url
terraform output classifier_api_name
```

Example output:
```
classifier_api_url = "https://profilepicapp-classifier-c2p7wl.azurewebsites.net"
classifier_api_name = "profilepicapp-classifier-c2p7wl"
```

## Deploying Classifier API Code

### Option 1: Zip Deployment (Recommended)

1. **Create deployment package:**
   ```powershell
   # From project root
   Compress-Archive -Path classifier_api.py, classifier_requirements.txt, models/* -DestinationPath classifier-deploy.zip -Force
   ```

2. **Deploy to Azure:**
   ```powershell
   az webapp deployment source config-zip `
     --name profilepicapp-classifier-c2p7wl `
     --resource-group profilepic-rg `
     --src classifier-deploy.zip
   ```

### Option 2: Git Deployment

```powershell
# Add Azure remote for classifier
git remote add azure-classifier https://profilepicapp-classifier-c2p7wl.scm.azurewebsites.net:443/profilepicapp-classifier-c2p7wl.git

# Push to Azure
git push azure-classifier main:master
```

### Option 3: VS Code Extension

1. Install "Azure App Service" extension
2. Right-click on classifier files
3. Select "Deploy to Web App"
4. Choose the classifier App Service

## Post-Deployment Configuration

### 1. Verify Deployment

```powershell
# Check health endpoint
curl https://profilepicapp-classifier-c2p7wl.azurewebsites.net/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "model_loaded": false,  # or true if model is deployed
  "classes": ["animal", "avatar", "human"]
}
```

### 2. Upload Model File (If Not in Deployment)

Use Azure CLI or Azure Portal to upload your model:

```powershell
# Using Azure CLI (if you have model locally)
az webapp deployment source config-zip `
  --name profilepicapp-classifier-c2p7wl `
  --resource-group profilepic-rg `
  --src classifier-with-model.zip
```

Or use Kudu console:
1. Go to https://profilepicapp-classifier-c2p7wl.scm.azurewebsites.net
2. Navigate to Debug Console > CMD
3. Go to site/wwwroot/models/
4. Upload your .keras or .h5 file

### 3. Configure Main App

Update your main Flask app to use the classifier API:

```python
# In app.py or config.py
CLASSIFIER_API_URL = "https://profilepicapp-classifier-c2p7wl.azurewebsites.net"

# Example usage
import requests

def classify_image(image_url):
    response = requests.post(
        f"{CLASSIFIER_API_URL}/api/classify/url",
        json={"image_url": image_url}
    )
    return response.json()
```

## Cost Estimation

### With Classifier API Enabled

| Resource | SKU | Monthly Cost (USD)* |
|----------|-----|---------------------|
| Main App | F1 (Free) | $0 |
| Classifier API | B1 (Basic) | ~$13 |
| **Total** | | **~$13/month** |

*Prices are estimates for West US 2 region (October 2025)

### Scaling Options

| SKU | vCores | RAM | Monthly Cost* | Use Case |
|-----|--------|-----|---------------|----------|
| B1 | 1 | 1.75 GB | ~$13 | Development/Testing |
| B2 | 2 | 3.5 GB | ~$26 | Light Production |
| S1 | 1 | 1.75 GB | ~$70 | Production with SLA |
| P1V2 | 1 | 3.5 GB | ~$96 | High-performance |

To change SKU, update `terraform.tfvars`:
```hcl
classifier_api_sku = "B2"  # or S1, P1V2, etc.
```

## Disabling Classifier API

To remove the classifier API and stop costs:

1. **Edit terraform.tfvars:**
   ```hcl
   enable_classifier_api = false
   ```

2. **Apply changes:**
   ```powershell
   cd terraform
   terraform apply
   ```

This will destroy:
- Classifier API App Service
- Classifier API App Service Plan

## Monitoring

### View Logs

```powershell
# Stream logs
az webapp log tail --name profilepicapp-classifier-c2p7wl --resource-group profilepic-rg

# Download logs
az webapp log download --name profilepicapp-classifier-c2p7wl --resource-group profilepic-rg --log-file classifier-logs.zip
```

### Application Insights (Optional)

To enable monitoring, update `terraform.tfvars`:
```hcl
enable_application_insights = true
```

This adds ~$0-$5/month depending on usage.

## Troubleshooting

### Issue: Model Not Loading

**Symptoms:** `/api/health` shows `"model_loaded": false`

**Solutions:**
1. Verify model file is in `models/` directory
2. Check file name: `profile_classifier.keras` or `profile_classifier.h5`
3. Review deployment logs for errors
4. Check app settings: `az webapp config appsettings list`

### Issue: Out of Memory

**Symptoms:** App crashes or restarts frequently

**Solutions:**
1. Upgrade to B2 or higher SKU (more RAM)
2. Optimize model size (use quantization)
3. Reduce batch size in preprocessing

### Issue: CORS Errors

**Symptoms:** Browser blocks API calls from main app

**Solutions:**
1. Verify main app hostname in CORS settings
2. Add additional origins to `classifier_allowed_origins` in `terraform.tfvars`
3. Check browser console for specific CORS error

### Issue: Slow Predictions

**Symptoms:** API takes >30 seconds to respond

**Solutions:**
1. Enable `always_on` (already enabled for B1+)
2. Upgrade to higher SKU for more CPU
3. Optimize model architecture
4. Add caching for frequently classified images

## Best Practices

1. **Keep Model Small**: Larger models need more RAM (B2+)
2. **Use Python 3.11**: Better TensorFlow compatibility than 3.13
3. **Enable Always On**: Prevents cold starts (included in B1+)
4. **Monitor Costs**: Check Azure Cost Management regularly
5. **Use Deployment Slots**: Test changes in staging before production (requires S1+)
6. **Version Your Models**: Include version in model filename
7. **Implement Caching**: Cache predictions for common images
8. **Set Up Alerts**: Monitor memory usage and response times

## Integration Example

```python
# In your main Flask app (app.py)
import requests
import os

CLASSIFIER_API_URL = os.getenv(
    'CLASSIFIER_API_URL',
    'https://profilepicapp-classifier-c2p7wl.azurewebsites.net'
)

@app.route('/classify/<username>')
@login_required
def classify_user_photo(username):
    # Get user's photo URL from CSV
    user_data = photo_mappings.get(username.lower())
    
    if not user_data or not user_data.get('BlobUrl'):
        return jsonify({'error': 'No photo found'}), 404
    
    # Call classifier API
    try:
        response = requests.post(
            f"{CLASSIFIER_API_URL}/api/classify/url",
            json={'image_url': user_data['BlobUrl']},
            timeout=30
        )
        result = response.json()
        
        return jsonify({
            'username': username,
            'actual_category': user_data.get('Category'),
            'predicted_category': result.get('predicted_class'),
            'confidence': result.get('confidence'),
            'probabilities': result.get('probabilities')
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500
```

## Next Steps

1. ✅ Apply Terraform changes
2. ✅ Deploy classifier API code
3. ✅ Upload trained model
4. ✅ Test health endpoint
5. ✅ Integrate with main app
6. ✅ Monitor performance and costs

## Documentation

- **Terraform Documentation**: [terraform/TERRAFORM_DEPLOYMENT.md](TERRAFORM_DEPLOYMENT.md)
- **Classifier API Documentation**: [CLASSIFIER_API.md](../CLASSIFIER_API.md)
- **Quick Start**: [QUICKSTART.md](../QUICKSTART.md)

---

**Last Updated**: October 24, 2025  
**Status**: Ready for deployment
