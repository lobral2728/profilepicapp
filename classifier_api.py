"""
CNN Classifier API Server
Provides image classification endpoint for profile pictures.
"""
import os
import io
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
from PIL import Image
import tensorflow as tf
from tensorflow import keras

app = Flask(__name__)
CORS(app)  # Enable CORS for cross-origin requests

# Global variable to hold the model
model = None
CLASS_LABELS = ['animal', 'avatar', 'human']

def load_model():
    """Load the pre-trained CNN model."""
    global model
    
    # Try to load the model from different possible paths
    model_paths = [
        'models/resnet50_profilepic_classifier.keras',  # ResNet50 model
        'models/profile_classifier.keras',
        'models/profile_classifier.h5',
        '../models/resnet50_profilepic_classifier.keras',
        '../models/profile_classifier.h5',
        '../models/profile_classifier.keras',
        os.path.join(os.path.dirname(__file__), 'models', 'resnet50_profilepic_classifier.keras'),
        os.path.join(os.path.dirname(__file__), 'models', 'profile_classifier.h5'),
        os.path.join(os.path.dirname(__file__), 'models', 'profile_classifier.keras'),
    ]
    
    for model_path in model_paths:
        if os.path.exists(model_path):
            try:
                print(f"Loading model from: {model_path}")
                model = keras.models.load_model(model_path)
                print(f"✓ Model loaded successfully!")
                print(f"  Input shape: {model.input_shape}")
                print(f"  Output shape: {model.output_shape}")
                return True
            except Exception as e:
                print(f"Error loading model from {model_path}: {e}")
                continue
    
    print("WARNING: No model found. Using mock predictions for testing.")
    return False


def preprocess_image(image_file):
    """
    Preprocess the image for the CNN model.
    
    Args:
        image_file: File object or bytes
        
    Returns:
        numpy array ready for model prediction
    """
    try:
        # Open image
        if isinstance(image_file, bytes):
            img = Image.open(io.BytesIO(image_file))
        else:
            img = Image.open(image_file)
        
        # Convert to RGB if needed
        if img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Resize to model input size (adjust based on your model)
        # Common sizes: 224x224, 128x128, 64x64
        target_size = (128, 128)  # Adjust to match your model's input
        img = img.resize(target_size, Image.LANCZOS)
        
        # Convert to numpy array and normalize
        img_array = np.array(img, dtype=np.float32)
        img_array = img_array / 255.0  # Normalize to [0, 1]
        
        # Add batch dimension
        img_array = np.expand_dims(img_array, axis=0)
        
        return img_array
    
    except Exception as e:
        raise ValueError(f"Error preprocessing image: {str(e)}")


def mock_prediction(img_array):
    """
    Mock prediction for testing when model is not available.
    Returns random predictions.
    """
    # Generate random probabilities that sum to 1
    probs = np.random.dirichlet(np.ones(3))
    predicted_class_idx = np.argmax(probs)
    
    return {
        'predicted_class': CLASS_LABELS[predicted_class_idx],
        'confidence': float(probs[predicted_class_idx]),
        'probabilities': {
            'animal': float(probs[0]),
            'avatar': float(probs[1]),
            'human': float(probs[2])
        },
        'mock': True
    }


@app.route('/')
def index():
    """API information endpoint."""
    return jsonify({
        'name': 'Profile Picture Classifier API',
        'version': '1.0.0',
        'status': 'running',
        'model_loaded': model is not None,
        'endpoints': {
            'classify': '/api/classify - POST multipart/form-data with "image" field',
            'health': '/api/health - GET health check'
        }
    })


@app.route('/api/health')
def health():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'model_loaded': model is not None,
        'classes': CLASS_LABELS
    })


@app.route('/api/classify', methods=['POST'])
def classify_image():
    """
    Classify an uploaded image.
    
    Expected: multipart/form-data with 'image' field containing the image file
    
    Returns:
        JSON with classification results:
        {
            'success': true,
            'predicted_class': 'human',
            'confidence': 0.95,
            'probabilities': {
                'animal': 0.02,
                'avatar': 0.03,
                'human': 0.95
            }
        }
    """
    try:
        # Check if image file is present
        if 'image' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No image file provided. Please upload an image with key "image".'
            }), 400
        
        image_file = request.files['image']
        
        # Check if filename is empty
        if image_file.filename == '':
            return jsonify({
                'success': False,
                'error': 'No image file selected.'
            }), 400
        
        # Preprocess the image
        img_array = preprocess_image(image_file)
        
        # Make prediction
        if model is not None:
            # Use actual model
            predictions = model.predict(img_array, verbose=0)
            predicted_class_idx = np.argmax(predictions[0])
            confidence = float(predictions[0][predicted_class_idx])
            
            result = {
                'success': True,
                'predicted_class': CLASS_LABELS[predicted_class_idx],
                'confidence': confidence,
                'probabilities': {
                    'animal': float(predictions[0][0]),
                    'avatar': float(predictions[0][1]),
                    'human': float(predictions[0][2])
                },
                'mock': False
            }
        else:
            # Use mock prediction for testing
            result = mock_prediction(img_array)
            result['success'] = True
            result['warning'] = 'Using mock predictions - no model loaded'
        
        return jsonify(result), 200
    
    except ValueError as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Internal server error: {str(e)}'
        }), 500


@app.route('/api/classify/url', methods=['POST'])
def classify_image_url():
    """
    Classify an image from a URL.
    
    Expected: JSON with 'image_url' field
    
    Returns: Same format as /api/classify
    """
    try:
        import requests
        
        data = request.get_json()
        if not data or 'image_url' not in data:
            return jsonify({
                'success': False,
                'error': 'No image_url provided in JSON body.'
            }), 400
        
        image_url = data['image_url']
        
        # Download the image
        response = requests.get(image_url, timeout=10)
        response.raise_for_status()
        
        # Preprocess the image
        img_array = preprocess_image(response.content)
        
        # Make prediction
        if model is not None:
            predictions = model.predict(img_array, verbose=0)
            predicted_class_idx = np.argmax(predictions[0])
            confidence = float(predictions[0][predicted_class_idx])
            
            result = {
                'success': True,
                'predicted_class': CLASS_LABELS[predicted_class_idx],
                'confidence': confidence,
                'probabilities': {
                    'animal': float(predictions[0][0]),
                    'avatar': float(predictions[0][1]),
                    'human': float(predictions[0][2])
                },
                'mock': False
            }
        else:
            result = mock_prediction(img_array)
            result['success'] = True
            result['warning'] = 'Using mock predictions - no model loaded'
        
        return jsonify(result), 200
    
    except requests.RequestException as e:
        return jsonify({
            'success': False,
            'error': f'Failed to download image: {str(e)}'
        }), 400
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'Internal server error: {str(e)}'
        }), 500


if __name__ == '__main__':
    print("=" * 60)
    print("Profile Picture Classifier API")
    print("=" * 60)
    
    # Create models directory if it doesn't exist
    os.makedirs('models', exist_ok=True)
    
    # Load the model
    load_model()
    
    print("\nStarting API server...")
    print("Available endpoints:")
    print("  - GET  /              - API information")
    print("  - GET  /api/health    - Health check")
    print("  - POST /api/classify  - Classify uploaded image")
    print("  - POST /api/classify/url - Classify image from URL")
    print("=" * 60)
    
    # Run the server
    app.run(host='0.0.0.0', port=5001, debug=True)
