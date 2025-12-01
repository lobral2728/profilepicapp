"""
Flask web application to display Entra ID profile pictures.
"""
import os
import csv
import requests
from flask import Flask, render_template, redirect, url_for, session, request
from msal import ConfidentialClientApplication
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'dev-secret-key-change-in-production')

# Azure AD / Entra ID Configuration
CLIENT_ID = os.getenv('CLIENT_ID')
CLIENT_SECRET = os.getenv('CLIENT_SECRET')
TENANT_ID = os.getenv('TENANT_ID')
REDIRECT_URI = os.getenv('REDIRECT_URI', 'http://localhost:5000/auth/callback')

AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"
SCOPE = ["User.Read", "User.ReadBasic.All"]

# Microsoft Graph API endpoint
GRAPH_API_ENDPOINT = "https://graph.microsoft.com/v1.0"

# Load photo URL mappings from CSV
PHOTO_MAPPING = {}
USER_LIST = []  # List of all users with photos

# Try multiple possible CSV paths
CSV_PATHS = [
    os.path.join(os.path.dirname(__file__), 'scripts', 'test_images', 'profile_upload_map.csv'),
    os.path.join(os.path.dirname(__file__), 'profile_upload_map.csv'),
    'scripts/test_images/profile_upload_map.csv',
    'profile_upload_map.csv'
]

def load_photo_mappings():
    """Load photo URL mappings from CSV file."""
    global PHOTO_MAPPING, USER_LIST
    
    csv_path = None
    for path in CSV_PATHS:
        if os.path.exists(path):
            csv_path = path
            break
    
    if csv_path:
        print(f"Found CSV at: {csv_path}")
        try:
            with open(csv_path, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    # Map userPrincipalName to blob URL (lowercase for case-insensitive lookup)
                    upn = row['UserPrincipalName'].lower()
                    PHOTO_MAPPING[upn] = row['BlobUrl']
                    # Store user info for browsing
                    USER_LIST.append({
                        'userPrincipalName': row['UserPrincipalName'],
                        'displayName': row['DisplayName'],
                        'blobUrl': row['BlobUrl'],
                        'category': row.get('Category', 'unknown')
                    })
            print(f"✓ Loaded {len(PHOTO_MAPPING)} photo mappings from CSV")
            print(f"✓ User list contains {len(USER_LIST)} users")
        except Exception as e:
            print(f"Error loading CSV: {e}")
    else:
        print(f"WARNING: CSV file not found in any of these locations:")
        for path in CSV_PATHS:
            print(f"  - {path}")
        print(f"Current directory: {os.getcwd()}")
        print(f"Script directory: {os.path.dirname(__file__)}")

# Load mappings on startup
load_photo_mappings()


def get_msal_app():
    """Create and return MSAL application instance."""
    return ConfidentialClientApplication(
        CLIENT_ID,
        authority=AUTHORITY,
        client_credential=CLIENT_SECRET
    )


@app.route('/')
def index():
    """Home page - shows login button if not authenticated."""
    if 'user' in session:
        return render_template('profile.html', user=session['user'])
    return render_template('index.html')


@app.route('/login')
def login():
    """Initiate OAuth2 login flow."""
    msal_app = get_msal_app()
    auth_url = msal_app.get_authorization_request_url(
        SCOPE,
        redirect_uri=REDIRECT_URI
    )
    return redirect(auth_url)


@app.route('/auth/callback')
def auth_callback():
    """Handle OAuth2 callback."""
    code = request.args.get('code')
    if not code:
        return "Error: No authorization code received", 400
    
    msal_app = get_msal_app()
    result = msal_app.acquire_token_by_authorization_code(
        code,
        scopes=SCOPE,
        redirect_uri=REDIRECT_URI
    )
    
    if "error" in result:
        return f"Error: {result.get('error_description')}", 400
    
    # Store access token in session
    session['access_token'] = result['access_token']
    
    # Get user profile
    user_info = get_user_profile(result['access_token'])
    if user_info:
        session['user'] = user_info
    
    return redirect(url_for('index'))


@app.route('/logout')
def logout():
    """Clear session and logout."""
    session.clear()
    return redirect(url_for('index'))


@app.route('/debug/status')
def debug_status():
    """Debug endpoint to check CSV loading status."""
    return {
        'csv_loaded': len(PHOTO_MAPPING) > 0,
        'total_mappings': len(PHOTO_MAPPING),
        'total_users': len(USER_LIST),
        'sample_upns': list(PHOTO_MAPPING.keys())[:5] if PHOTO_MAPPING else []
    }


@app.route('/debug/test-classifier')
def test_classifier():
    """Test endpoint to verify connectivity to the classifier API."""
    if 'access_token' not in session:
        return redirect(url_for('login'))
    
    classifier_url = os.getenv('CLASSIFIER_API_URL', 'https://profilepicapp-classifier-c2p7wl.azurewebsites.net')
    
    results = {
        'classifier_url': classifier_url,
        'tests': {}
    }
    
    # Test 1: Health check
    try:
        health_url = f"{classifier_url}/api/health"
        response = requests.get(health_url, timeout=90)
        results['tests']['health_check'] = {
            'status': 'success' if response.status_code == 200 else 'failed',
            'status_code': response.status_code,
            'response': response.json() if response.status_code == 200 else response.text[:200]
        }
    except Exception as e:
        results['tests']['health_check'] = {
            'status': 'error',
            'error': str(e)
        }
    
    # Test 2: Root endpoint
    try:
        root_url = f"{classifier_url}/"
        response = requests.get(root_url, timeout=90)
        results['tests']['root_endpoint'] = {
            'status': 'success' if response.status_code == 200 else 'failed',
            'status_code': response.status_code,
            'response': response.text[:200]
        }
    except Exception as e:
        results['tests']['root_endpoint'] = {
            'status': 'error',
            'error': str(e)
        }
    
    # Test 3: Classify a test image (if we have one)
    if USER_LIST:
        try:
            test_user = USER_LIST[0]
            if test_user.get('BlobUrl'):
                classify_url = f"{classifier_url}/api/classify/url"
                payload = {'image_url': test_user['BlobUrl']}
                response = requests.post(classify_url, json=payload, timeout=30)
                results['tests']['classify_image'] = {
                    'status': 'success' if response.status_code == 200 else 'failed',
                    'status_code': response.status_code,
                    'test_image': test_user['BlobUrl'],
                    'response': response.json() if response.status_code == 200 else response.text[:200]
                }
        except Exception as e:
            results['tests']['classify_image'] = {
                'status': 'error',
                'error': str(e)
            }
    
    return results


@app.route('/browse')
@app.route('/browse/<int:index>')
def browse_profiles(index=0):
    """Browse through all user profiles with navigation."""
    if 'access_token' not in session:
        return redirect(url_for('login'))
    
    # Ensure index is within bounds
    if index < 0:
        index = 0
    elif index >= len(USER_LIST):
        index = len(USER_LIST) - 1
    
    if not USER_LIST:
        return "No users found", 404
    
    current_user = USER_LIST[index]
    
    return render_template('browse.html', 
                          user=current_user,
                          current_index=index,
                          total_users=len(USER_LIST),
                          has_prev=index > 0,
                          has_next=index < len(USER_LIST) - 1)


@app.route('/gallery')
def gallery():
    """Display all users in a grid gallery view."""
    if 'access_token' not in session:
        return redirect(url_for('login'))
    
    if not USER_LIST:
        return "No users found", 404
    
    return render_template('gallery.html', 
                          users=USER_LIST,
                          total_users=len(USER_LIST))


@app.route('/profile/photo')
def profile_photo():
    """Fetch and return user's profile photo from blob storage."""
    if 'user' not in session:
        return "Unauthorized", 401
    
    # Get user's UPN from session
    user_upn = session['user'].get('userPrincipalName', '').lower()
    
    # Check if we have a blob URL for this user
    if user_upn in PHOTO_MAPPING:
        return redirect(PHOTO_MAPPING[user_upn])
    else:
        # No photo available - return placeholder
        return redirect(url_for('static', filename='placeholder.png'))


@app.route('/user/<user_id>/photo')
def user_photo(user_id):
    """Fetch profile photo for a specific user by ID or UPN from blob storage."""
    if 'access_token' not in session:
        return "Unauthorized", 401
    
    # If user_id looks like a UPN, use it directly
    if '@' in user_id:
        user_upn = user_id.lower()
    else:
        # Need to fetch user info from Graph to get UPN
        headers = {'Authorization': f"Bearer {session['access_token']}"}
        response = requests.get(f"{GRAPH_API_ENDPOINT}/users/{user_id}", headers=headers)
        
        if response.status_code == 200:
            user_data = response.json()
            user_upn = user_data.get('userPrincipalName', '').lower()
        else:
            return redirect(url_for('static', filename='placeholder.png'))
    
    # Check if we have a blob URL for this user
    if user_upn in PHOTO_MAPPING:
        return redirect(PHOTO_MAPPING[user_upn])
    else:
        return redirect(url_for('static', filename='placeholder.png'))


def get_user_profile(access_token):
    """Get user profile information from Microsoft Graph."""
    headers = {'Authorization': f'Bearer {access_token}'}
    response = requests.get(f"{GRAPH_API_ENDPOINT}/me", headers=headers)
    
    if response.status_code == 200:
        return response.json()
    return None


if __name__ == '__main__':
    # Check if required environment variables are set
    if not all([CLIENT_ID, CLIENT_SECRET, TENANT_ID]):
        print("Error: Missing required environment variables!")
        print("Please set CLIENT_ID, CLIENT_SECRET, and TENANT_ID in .env file")
        exit(1)
    
    app.run(debug=True, host='0.0.0.0', port=5000)
