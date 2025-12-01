# Azure Portal Setup Guide

This guide walks you through setting up your Entra ID Profile Picture App in the Azure Portal.

---

## Step 1: Register Application in Microsoft Entra ID

### 1.1 Navigate to App Registrations

1. Open your web browser and go to [https://portal.azure.com](https://portal.azure.com)
2. Sign in with your Azure account
3. In the search bar at the top, type **"Microsoft Entra ID"** (or "Azure Active Directory")
4. Click on **Microsoft Entra ID** from the search results

### 1.2 Create a New App Registration

1. In the left sidebar, click **App registrations**
2. Click **+ New registration** at the top of the page
3. Fill in the registration form:

   **Name:**
   ```
   ProfilePicApp
   ```
   (You can choose any name you prefer)

   **Supported account types:**
   - Select **"Accounts in this organizational directory only (Single tenant)"**
     - Choose this if only users in your organization will use the app
   - OR select **"Accounts in any organizational directory (Any Azure AD directory - Multitenant)"**
     - Choose this if users from other organizations should be able to sign in

   **Redirect URI:**
   - From the dropdown, select **Web**
   - In the text box, enter: `http://localhost:5000/auth/callback`

4. Click **Register** button at the bottom

### 1.3 Copy Your Application IDs

After registration, you'll be taken to the app's Overview page.

1. **Copy the Application (client) ID:**
   - Look for **Application (client) ID** on the overview page
   - Click the copy icon next to it
   - Save this value - you'll need it for `CLIENT_ID` in your `.env` file
   - Example format: `12345678-1234-1234-1234-123456789abc`

2. **Copy the Directory (tenant) ID:**
   - Look for **Directory (tenant) ID** on the same page
   - Click the copy icon next to it
   - Save this value - you'll need it for `TENANT_ID` in your `.env` file
   - Example format: `87654321-4321-4321-4321-cba987654321`

---

## Step 2: Create a Client Secret

### 2.1 Navigate to Certificates & Secrets

1. In your app registration page, look at the left sidebar
2. Under **Manage**, click **Certificates & secrets**

### 2.2 Create a New Client Secret

1. Click on the **Client secrets** tab (should be selected by default)
2. Click **+ New client secret** button
3. Fill in the secret details:

   **Description:**
   ```
   ProfilePicApp Local Development Secret
   ```

   **Expires:**
   - Choose expiration period (recommended: **180 days (6 months)** or **Custom**)
   - For production, you'll want to rotate secrets regularly
   - For development, 6 months is typically sufficient

4. Click **Add**

### 2.3 Copy the Client Secret VALUE

⚠️ **CRITICAL:** You can only see the secret value immediately after creation!

1. After clicking Add, a new row will appear with your secret
2. Look for the **Value** column (NOT the "Secret ID")
3. Click the copy icon next to the Value
4. **Save this immediately** - you'll need it for `CLIENT_SECRET` in your `.env` file
5. Example format: `abC1~DEfGhiJklMnOpQrStUvWxYz0123456789`

⚠️ If you navigate away without copying the value, you'll need to create a new secret!

---

## Step 3: Configure API Permissions

### 3.1 Navigate to API Permissions

1. In your app registration, look at the left sidebar
2. Under **Manage**, click **API permissions**

### 3.2 Add Microsoft Graph Permissions

You should see one default permission already there (`User.Read`).

1. Click **+ Add a permission** button
2. In the flyout panel, click **Microsoft Graph**
3. Click **Delegated permissions**
4. Use the search box to find and add the following permissions:

   **Permission 1: User.Read** (should already be there)
   - If not present, search for "User.Read"
   - Expand **User** section
   - Check the box next to **User.Read**
   - Description: "Sign in and read user profile"

   **Permission 2: User.ReadBasic.All**
   - Search for "User.ReadBasic.All"
   - Expand **User** section
   - Check the box next to **User.ReadBasic.All**
   - Description: "Read all users' basic profiles"

5. Click **Add permissions** button at the bottom

### 3.3 Grant Admin Consent (If Required)

Some organizations require admin consent for apps to use these permissions.

1. Look at the permissions list
2. If you see yellow warning triangles or "Not granted" status, you need to grant consent
3. Click **Grant admin consent for [Your Organization]** button at the top
4. In the confirmation dialog, click **Yes**
5. All permissions should now show a green checkmark with "Granted for [Your Organization]"

**Note:** If you don't have admin privileges and can't grant consent:
- Contact your Azure AD administrator
- OR use a personal Microsoft account/tenant where you have admin rights

---

## Step 4: Configure Your Local Environment File

Now that you have all the credentials from Azure, let's set up your local configuration.

### 4.1 Create the .env File

1. Open VS Code (if not already open)
2. In the terminal, run:
   ```powershell
   Copy-Item .env.example .env
   ```
3. Open the new `.env` file in VS Code

### 4.2 Fill in Your Credentials

Replace the placeholder values with your actual credentials from Azure:

```env
# Azure AD / Entra ID Configuration
CLIENT_ID=paste-your-application-client-id-here
CLIENT_SECRET=paste-your-client-secret-value-here
TENANT_ID=paste-your-directory-tenant-id-here

# Flask Configuration
FLASK_SECRET_KEY=generate-a-random-secret-key-here

# Redirect URI (for local development)
REDIRECT_URI=http://localhost:5000/auth/callback
```

### 4.3 Generate a Flask Secret Key

The Flask secret key is used to encrypt session data. Generate a secure random key:

1. In VS Code terminal (with venv activated), run:
   ```powershell
   python -c "import secrets; print(secrets.token_hex(32))"
   ```
2. Copy the output (a long random string)
3. Paste it as the value for `FLASK_SECRET_KEY` in your `.env` file

Your final `.env` file should look like this (with your actual values):

```env
# Azure AD / Entra ID Configuration
CLIENT_ID=12345678-1234-1234-1234-123456789abc
CLIENT_SECRET=abC1~DEfGhiJklMnOpQrStUvWxYz0123456789
TENANT_ID=87654321-4321-4321-4321-cba987654321

# Flask Configuration
FLASK_SECRET_KEY=a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456

# Redirect URI (for local development)
REDIRECT_URI=http://localhost:5000/auth/callback
```

### 4.4 Save and Verify

1. Save the `.env` file (Ctrl + S)
2. ⚠️ **NEVER** commit this file to Git (it's already in `.gitignore`)
3. Verify all values are filled in with no placeholder text

---

## Step 5: Test Your Application Locally

Now let's verify everything works!

### 5.1 Activate Virtual Environment and Run

1. In VS Code terminal, make sure your virtual environment is activated:
   ```powershell
   .\venv\Scripts\Activate.ps1
   ```
   You should see `(venv)` at the beginning of your prompt

2. Run the Flask application:
   ```powershell
   python app.py
   ```

3. You should see output like:
   ```
   * Serving Flask app 'app'
   * Debug mode: on
   * Running on http://0.0.0.0:5000
   ```

### 5.2 Test in Your Browser

1. Open your web browser
2. Navigate to: `http://localhost:5000`
3. You should see the login page with "Sign in with Microsoft" button
4. Click the button
5. You'll be redirected to Microsoft's login page
6. Sign in with your Microsoft account (from your tenant)
7. You may be asked to consent to permissions (click Accept)
8. You should be redirected back to your app showing your profile and photo!

### 5.3 Troubleshooting

**If you see "Error: Missing required environment variables"**
- Your `.env` file is not properly configured
- Check that all values are filled in
- Make sure there are no quotes around the values

**If you get authentication errors:**
- Verify your CLIENT_ID, CLIENT_SECRET, and TENANT_ID are correct
- Check that the redirect URI in Azure exactly matches `http://localhost:5000/auth/callback`
- Ensure API permissions are granted in Azure Portal

**If you see "No photo available":**
- This is normal if your account doesn't have a profile photo set
- Go to office.com → click your profile picture → Upload a photo
- Then try the app again

---

## Next Steps: Deploying to Azure

Once your app works locally, you're ready to deploy to Azure! The next guide will cover:

1. Creating Azure App Service resources
2. Deploying your code
3. Configuring production environment variables
4. Updating your app registration for production URLs

Would you like the deployment guide next?

---

## Quick Reference: What You'll Need

✅ **From Azure Portal:**
- Application (client) ID → `CLIENT_ID`
- Directory (tenant) ID → `TENANT_ID`
- Client secret value → `CLIENT_SECRET`

✅ **Generated Locally:**
- Flask secret key → `FLASK_SECRET_KEY`

✅ **Static Values:**
- Redirect URI (local) → `http://localhost:5000/auth/callback`
- Redirect URI (production) → `https://your-app-name.azurewebsites.net/auth/callback`

---

## Security Reminders

🔒 **Never commit `.env` to version control**
🔒 **Rotate secrets regularly (every 3-6 months)**
🔒 **Use different secrets for dev and production**
🔒 **Keep your Client Secret secure - treat it like a password**

---

Need help? Check the main README.md or open an issue on GitHub.
