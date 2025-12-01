# Profile Picture Classifier API

A Flask-based REST API that uses a CNN model to classify profile pictures into three categories: **human**, **avatar**, or **animal**.

## Features

- 🤖 **CNN Model Integration**: Load and use pre-trained TensorFlow/Keras models
- 🖼️ **Multiple Input Methods**: Upload files or provide image URLs
- 📊 **Detailed Predictions**: Returns probabilities for all classes
- 🔄 **Mock Mode**: Falls back to mock predictions if no model is available (for testing)
- 🌐 **CORS Enabled**: Can be called from web applications
- ✅ **Health Checks**: Monitor API and model status

## Installation

### 1. Install Dependencies

```bash
pip install -r classifier_requirements.txt
```

Required packages:
- Flask 3.1.0
- flask-cors 5.0.0
- TensorFlow 2.18.0
- Pillow 11.0.0
- NumPy 2.1.3
- requests 2.32.3

### 2. Add Your Model

Place your trained model in the `models/` directory:
- `models/profile_classifier.h5` (HDF5 format)
- `models/profile_classifier.keras` (Keras format)

**Model Requirements:**
- Input shape: (128, 128, 3) - RGB images, 128x128 pixels
- Output shape: (3,) - probabilities for [animal, avatar, human]
- Output order: Must match `['animal', 'avatar', 'human']`

If no model is found, the API will use **mock predictions** for testing purposes.

## Usage

### Start the Server

```bash
python classifier_api.py
```

The server will start on `http://localhost:5001`

### API Endpoints

#### 1. Health Check
```bash
GET /api/health
```

Response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "classes": ["animal", "avatar", "human"]
}
```

#### 2. Classify Uploaded Image
```bash
POST /api/classify
Content-Type: multipart/form-data
```

Form data:
- `image`: Image file (JPG, PNG, etc.)

Example using `curl`:
```bash
curl -X POST -F "image=@path/to/image.jpg" http://localhost:5001/api/classify
```

Example using Python:
```python
import requests

with open('image.jpg', 'rb') as f:
    files = {'image': f}
    response = requests.post('http://localhost:5001/api/classify', files=files)
    result = response.json()
    print(result)
```

Response:
```json
{
  "success": true,
  "predicted_class": "human",
  "confidence": 0.95,
  "probabilities": {
    "animal": 0.02,
    "avatar": 0.03,
    "human": 0.95
  },
  "mock": false
}
```

#### 3. Classify Image from URL
```bash
POST /api/classify/url
Content-Type: application/json
```

Body:
```json
{
  "image_url": "https://example.com/image.jpg"
}
```

Example:
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"image_url":"https://profilepicsto7826.blob.core.windows.net/profile-photos/profile_human_001.jpg"}' \
  http://localhost:5001/api/classify/url
```

## Testing

Use the included test client:

```bash
python test_classifier_api.py
```

This will:
1. Check API health
2. Test file upload classification
3. Test URL-based classification
4. Test batch classification of multiple images

## Integration with Profile Picture App

To integrate with the main Flask app, you can:

1. **Call from frontend JavaScript**:
```javascript
async function classifyImage(imageUrl) {
    const response = await fetch('http://localhost:5001/api/classify/url', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({image_url: imageUrl})
    });
    return await response.json();
}
```

2. **Call from backend Python**:
```python
import requests

def classify_profile_picture(image_url):
    response = requests.post(
        'http://localhost:5001/api/classify/url',
        json={'image_url': image_url}
    )
    return response.json()
```

## Model Configuration

If your CNN model uses different settings, modify these in `classifier_api.py`:

```python
# Image preprocessing size (line ~65)
target_size = (128, 128)  # Change to match your model

# Class labels and order (line ~18)
CLASS_LABELS = ['animal', 'avatar', 'human']  # Must match model output
```

## Error Handling

The API returns appropriate HTTP status codes:
- `200`: Success
- `400`: Bad request (invalid image, missing parameters)
- `500`: Internal server error

Error response format:
```json
{
  "success": false,
  "error": "Error message here"
}
```

## Deployment

### Development
```bash
python classifier_api.py
```

### Production (using Gunicorn)
```bash
gunicorn -w 4 -b 0.0.0.0:5001 classifier_api:app
```

Options:
- `-w 4`: 4 worker processes
- `-b 0.0.0.0:5001`: Bind to all interfaces on port 5001
- `--timeout 60`: Increase timeout for slow predictions

## Architecture

```
┌─────────────────┐
│  Profile App    │
│  (Flask)        │
└────────┬────────┘
         │ HTTP Request
         ▼
┌─────────────────┐
│ Classifier API  │
│  (Flask)        │
│  Port: 5001     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  CNN Model      │
│  (TensorFlow)   │
└─────────────────┘
```

## Notes

- The API runs on port **5001** to avoid conflicts with the main app (port 5000)
- CORS is enabled for all origins - restrict this in production
- Images are automatically resized and normalized for the model
- Supports RGB images; other formats are converted automatically
- Mock mode allows testing the API before you have a trained model

## Next Steps

1. **Train your CNN model** using the FairFace dataset and profile pictures
2. **Save the model** in Keras format to `models/profile_classifier.keras`
3. **Test the API** using the test client
4. **Integrate** with the main profile picture app
5. **Deploy** to Azure or your preferred hosting platform
