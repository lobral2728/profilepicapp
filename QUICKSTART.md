# Quick Start Guide - Classifier API

## Initial Setup

### 1. Run Setup Script
```bash
python setup_classifier.py
```

This will:
- Verify Python version compatibility
- Create the `models/` directory
- Install all required dependencies
- Verify package imports

### 2. Add Your Model File
Place your trained Keras model in the `models/` directory:
```
models/profile_classifier.keras  # or .h5
```

**Model Requirements:**
- Input: (128, 128, 3) RGB images
- Output: (3,) probabilities for [animal, avatar, human]

If you don't have a model yet, the API will use mock predictions.

## Running the API

### Start the Server
```bash
python classifier_api.py
```

Server runs on: `http://localhost:5001`

### Test the API
In a new terminal:
```bash
python test_classifier_api.py
```

## Basic Usage Examples

### 1. Health Check
```bash
curl http://localhost:5001/api/health
```

### 2. Classify Local Image
```bash
curl -X POST -F "image=@path/to/image.jpg" http://localhost:5001/api/classify
```

### 3. Classify Image URL
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"image_url":"https://example.com/image.jpg"}' \
  http://localhost:5001/api/classify/url
```

### 4. Python Client
```python
import requests

# Upload file
with open('image.jpg', 'rb') as f:
    response = requests.post('http://localhost:5001/api/classify', 
                            files={'image': f})
    print(response.json())

# URL classification
response = requests.post('http://localhost:5001/api/classify/url',
                        json={'image_url': 'https://example.com/image.jpg'})
print(response.json())
```

## File Structure

```
profilepicapp/
├── classifier_api.py              # Main API server
├── classifier_requirements.txt    # Dependencies
├── test_classifier_api.py        # Test client
├── setup_classifier.py           # Setup script
├── CLASSIFIER_API.md             # Full documentation
├── QUICKSTART.md                 # This file
└── models/
    ├── README.md                 # Model specifications
    └── profile_classifier.keras  # Your model (add this)
```

## Troubleshooting

### Python Version Issues
TensorFlow 2.18.0 requires Python 3.9-3.12. If you have Python 3.13+:
- Use a virtual environment with Python 3.11
- Or wait for TensorFlow to support Python 3.13

### Import Errors
```bash
pip install -r classifier_requirements.txt
```

### Port Already in Use
Change port in `classifier_api.py` line 123:
```python
app.run(debug=True, port=5002)  # Change from 5001
```

### Model Not Loading
Check:
1. Model file is in `models/` directory
2. File name is `profile_classifier.keras` or `.h5`
3. Model was saved correctly with TensorFlow/Keras

## Next Steps

1. **Test with mock predictions** (no model needed)
2. **Add your trained model** to `models/`
3. **Run full test suite** to verify accuracy
4. **Integrate with main app** (see CLASSIFIER_API.md)
5. **Deploy to Azure** (optional)

## Documentation

- **Full API docs**: `CLASSIFIER_API.md`
- **Model specs**: `models/README.md`
- **Test examples**: See `test_classifier_api.py`

## Support

For issues or questions, check the main README.md or CLASSIFIER_API.md
