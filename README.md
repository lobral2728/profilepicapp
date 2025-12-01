# Entra ID Profile Picture App

A simple Flask web application that displays Microsoft Entra ID (Azure AD) profile pictures using Microsoft Graph API.

## Features

- 🔐 Microsoft Authentication (OAuth2)
- 🖼️ Display user profile pictures from Azure Blob Storage
- 👤 Show user profile information
- 📸 Gallery view with 4-6 images across
- 🔍 Browse individual profiles with navigation
- 🤖 **NEW: CNN Classifier API** for image categorization
- 🎯 Categorize images as: human, avatar, or animal
- 🎨 Clean, modern UI
- ☁️ Deployed to Azure App Service

## Prerequisites

- Python 3.13+
- Azure subscription
- Microsoft Entra ID (Azure AD) tenant

## Setup Instructions

### 1. Register Application in Azure

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Entra ID** (formerly Azure AD)
3. Select **App registrations** → **New registration**
4. Configure your app:
   - **Name**: `ProfilePicApp` (or your preferred name)
   - **Supported account types**: Choose appropriate option (single or multi-tenant)
   - **Redirect URI**: Select `Web` and enter `http://localhost:5000/auth/callback`
5. Click **Register**
6. Note down the **Application (client) ID** and **Directory (tenant) ID**
7. Go to **Certificates & secrets** → **New client secret**
   - Add a description and select expiration period
   - Copy the **secret value** immediately (you won't see it again!)
8. Go to **API permissions**:
   - Click **Add a permission** → **Microsoft Graph** → **Delegated permissions**
   - Add: `User.Read` and `User.ReadBasic.All`
   - Click **Add permissions**
   - (Optional) Click **Grant admin consent** if required

### 2. Configure the Application

1. Copy the example environment file:
   ```powershell
   Copy-Item .env.example .env
   ```

2. Edit `.env` file with your Azure app details:
   ```
   CLIENT_ID=your-application-client-id
   CLIENT_SECRET=your-client-secret-value
   TENANT_ID=your-directory-tenant-id
   FLASK_SECRET_KEY=your-random-secret-key
   REDIRECT_URI=http://localhost:5000/auth/callback
   ```

3. Generate a secure Flask secret key (optional but recommended):
   ```powershell
   .\venv\Scripts\Activate.ps1
   python -c "import secrets; print(secrets.token_hex(32))"
   ```

### 3. Install Dependencies

```powershell
# Activate virtual environment
.\venv\Scripts\Activate.ps1

# Install packages (already done if you followed setup)
pip install -r requirements.txt
```

### 4. Run the Application Locally

```powershell
# Make sure virtual environment is activated
.\venv\Scripts\Activate.ps1

# Run the Flask app
python app.py
```

Visit `http://localhost:5000` in your browser.

## Project Structure

```
profilepicapp/
├── app.py                          # Main Flask application
├── config.py                       # Configuration settings
├── requirements.txt                # Main app dependencies
├── profile_upload_map.csv          # User to image mapping
├── .env.example                    # Example environment variables
├── .gitignore                      # Git ignore rules
│
├── templates/                      # HTML templates
│   ├── index.html                  # Login page
│   ├── profile.html                # Home page with links
│   ├── gallery.html                # Multi-image grid view
│   └── browse.html                 # Single profile navigation
│
├── scripts/                        # PowerShell scripts
│   ├── Create-EntraTestUsers.ps1   # Create test users
│   ├── Upload-ProfilePhotos-ToStorage.ps1
│   ├── Shuffle-ProfilePhotos.ps1   # Randomize assignments
│   └── test_images/                # Training images (101 images)
│       ├── human/                  # 51 diverse human faces
│       ├── avatar/                 # 25 cartoon faces
│       └── animal/                 # 25 cat/dog images
│
├── models/                         # CNN model directory
│   ├── README.md                   # Model specifications
│   └── .gitkeep                    # (Add your .keras file here)
│
├── classifier_api.py               # CNN classifier Flask API
├── classifier_requirements.txt     # Classifier dependencies
├── test_classifier_api.py         # API test client
├── setup_classifier.py            # Automated setup script
├── train_model_example.py         # Model training template
├── CLASSIFIER_API.md              # Full API documentation
├── QUICKSTART.md                  # Quick start guide
│
└── venv/                          # Virtual environment (not in git)
```

## Deploying to Azure

### Option 1: Azure App Service (Web App)

1. **Login to Azure CLI**:
   ```powershell
   az login
   ```

2. **Create a resource group**:
   ```powershell
   az group create --name profilepic-rg --location eastus
   ```

3. **Create an App Service Plan**:
   ```powershell
   az appservice plan create --name profilepic-plan --resource-group profilepic-rg --sku B1 --is-linux
   ```

4. **Create the Web App**:
   ```powershell
   az webapp create --resource-group profilepic-rg --plan profilepic-plan --name your-unique-app-name --runtime "PYTHON:3.13"
   ```

5. **Configure environment variables**:
   ```powershell
   az webapp config appsettings set --resource-group profilepic-rg --name your-unique-app-name --settings CLIENT_ID="your-client-id" CLIENT_SECRET="your-client-secret" TENANT_ID="your-tenant-id" FLASK_SECRET_KEY="your-secret-key" REDIRECT_URI="https://your-unique-app-name.azurewebsites.net/auth/callback"
   ```

6. **Update Azure App Registration**:
   - Go back to your app registration in Azure Portal
   - Add the production redirect URI: `https://your-unique-app-name.azurewebsites.net/auth/callback`

7. **Deploy the app**:
   ```powershell
   # Using Azure CLI
   az webapp up --resource-group profilepic-rg --name your-unique-app-name --runtime "PYTHON:3.13"
   ```

### Option 2: Azure Container Instances (Docker)

Coming soon...

## Troubleshooting

### "Error: Missing required environment variables"
- Make sure you've created a `.env` file from `.env.example`
- Verify all required values are filled in

### "Authentication failed"
- Check that your Client ID, Client Secret, and Tenant ID are correct
- Verify the redirect URI matches exactly in both `.env` and Azure app registration
- Ensure API permissions are granted in Azure Portal

### "No photo available"
- Some users may not have profile photos set in Entra ID
- The app will show a placeholder image in this case

## Security Notes

- Never commit `.env` file to git (it's in `.gitignore`)
- Use different secrets for development and production
- Rotate client secrets regularly
- Use managed identities when possible in Azure

## CNN Classifier API

This project includes a separate Flask API for classifying profile pictures using a CNN model.

### Quick Start

1. **Setup the classifier environment**:
   ```powershell
   python setup_classifier.py
   ```

2. **Add your trained model** to `models/` directory:
   - Place `profile_classifier.keras` or `profile_classifier.h5`
   - Or use mock predictions for testing

3. **Start the classifier API**:
   ```powershell
   python classifier_api.py
   ```

4. **Test the API**:
   ```powershell
   python test_classifier_api.py
   ```

### Documentation

- **Full API docs**: [CLASSIFIER_API.md](CLASSIFIER_API.md)
- **Quick start**: [QUICKSTART.md](QUICKSTART.md)
- **Model specs**: [models/README.md](models/README.md)

### API Endpoints

- `GET /api/health` - Check API and model status
- `POST /api/classify` - Classify uploaded image file
- `POST /api/classify/url` - Classify image from URL

### Model Training

The API expects a trained CNN model with:
- **Input**: (128, 128, 3) RGB images
- **Output**: (3,) probabilities for [animal, avatar, human]
- **Format**: `.keras` or `.h5` file

See `train_model_example.py` for a training template.

## Dataset

The project includes 121 test users with profile pictures:
- **51 human faces**: Diverse faces from FairFace dataset (ages 18-70)
- **25 avatars**: Cartoon human faces from CartoonSet100k
- **25 animals**: Cat and dog images
- **20 no picture**: Accounts without profile photos

Images are stored in Azure Blob Storage and mapped in `profile_upload_map.csv`.

## Technologies Used

- **Flask 3.1.0** - Web framework
- **MSAL 1.31.1** - OAuth2 authentication
- **TensorFlow 2.18.0** - CNN model framework
- **Pillow 11.0.0** - Image preprocessing
- **Azure Blob Storage** - Profile picture hosting
- **Microsoft Entra ID** - User authentication
- **Azure App Service** - Production hosting

## Live Deployment

- **Main App**: https://profilepicapp-c2p7wl.azurewebsites.net
- **Storage**: profilepicsto7826.blob.core.windows.net
- **Tenant**: lobralicloud.onmicrosoft.com

## License

MIT License
