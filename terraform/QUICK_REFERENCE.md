# Quick Reference - Terraform Classifier API Deployment

## Prerequisites
- ✅ Terraform installed
- ✅ Azure CLI logged in (`az login`)
- ✅ Classifier API code ready
- ✅ (Optional) Trained model file

## Deployment Commands

### 1. Review Changes
```powershell
cd terraform
terraform plan
```

### 2. Deploy Infrastructure
```powershell
terraform apply
# Type 'yes' to confirm
```

### 3. Get Classifier API URL
```powershell
terraform output classifier_api_url
# Output: https://profilepicapp-classifier-c2p7wl.azurewebsites.net
```

### 4. Deploy API Code
```powershell
# Go back to project root
cd ..

# Create deployment package
Compress-Archive -Path `
  classifier_api.py, `
  classifier_requirements.txt, `
  models -DestinationPath classifier-deploy.zip -Force

# Deploy to Azure
az webapp deployment source config-zip `
  --name $(terraform -chdir=terraform output -raw classifier_api_name) `
  --resource-group profilepic-rg `
  --src classifier-deploy.zip
```

### 5. Verify Deployment
```powershell
# Test health endpoint
$url = terraform -chdir=terraform output -raw classifier_api_url
curl "$url/api/health"
```

Expected output:
```json
{
  "status": "healthy",
  "model_loaded": false,
  "classes": ["animal", "avatar", "human"]
}
```

## Configuration Options

### Enable/Disable Classifier API
Edit `terraform/terraform.tfvars`:
```hcl
enable_classifier_api = true   # or false to disable
```

### Change SKU (Performance/Cost)
```hcl
classifier_api_sku = "B1"   # B1, B2, S1, S2, P1V2, etc.
```

### Add CORS Origins
```hcl
classifier_allowed_origins = ["https://example.com"]
```

## Cost Reference

| SKU | vCPU | RAM | Monthly Cost | Notes |
|-----|------|-----|--------------|-------|
| B1 | 1 | 1.75 GB | ~$13 | Recommended minimum |
| B2 | 2 | 3.5 GB | ~$26 | Better performance |
| S1 | 1 | 1.75 GB | ~$70 | Production with SLA |

## Useful Commands

```powershell
# View all outputs
terraform output

# Get specific output (no quotes)
terraform output -raw classifier_api_name

# View current state
terraform show

# Destroy classifier resources
# (set enable_classifier_api = false, then apply)

# View deployment logs
az webapp log tail --name <classifier-api-name> --resource-group profilepic-rg

# SSH into app (for debugging)
az webapp ssh --name <classifier-api-name> --resource-group profilepic-rg

# Restart app
az webapp restart --name <classifier-api-name> --resource-group profilepic-rg
```

## Troubleshooting

### Issue: "terraform: command not found"
**Solution**: Install Terraform or use full path

### Issue: "Error acquiring state lock"
**Solution**: Wait for other operations to complete, or force-unlock if stuck

### Issue: "Quota exceeded"
**Solution**: Try different region or request quota increase

### Issue: Deployment fails with TensorFlow errors
**Solution**: Check Python version (should be 3.11), verify requirements.txt

### Issue: Model not loading
**Solution**: Ensure model file is in models/ directory in deployment package

## Integration with Main App

```python
# Add to app.py
import os
import requests

CLASSIFIER_API_URL = os.getenv(
    'CLASSIFIER_API_URL',
    'https://profilepicapp-classifier-c2p7wl.azurewebsites.net'
)

def classify_image(image_url):
    """Classify an image using the classifier API"""
    try:
        response = requests.post(
            f"{CLASSIFIER_API_URL}/api/classify/url",
            json={"image_url": image_url},
            timeout=30
        )
        return response.json()
    except Exception as e:
        return {"error": str(e)}
```

## Security Notes

- ✅ HTTPS enforced on both services
- ✅ CORS configured for main app
- ✅ Secrets stored in Terraform state (secure state backend recommended)
- ⚠️ Consider using Azure Key Vault for production secrets
- ⚠️ Rotate credentials regularly

## Documentation

- **Full Guide**: `terraform/CLASSIFIER_DEPLOYMENT.md`
- **Terraform Docs**: `terraform/TERRAFORM_DEPLOYMENT.md`
- **API Docs**: `CLASSIFIER_API.md`

---
**Last Updated**: October 24, 2025
