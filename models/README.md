# Model Directory

This directory contains the trained CNN model files for profile picture classification.

## Required Model File

Place your trained Keras model here with one of these names:
- `profile_classifier.keras` (recommended - native Keras format)
- `profile_classifier.h5` (legacy HDF5 format)

## Model Specifications

### Input
- **Shape**: `(128, 128, 3)`
- **Type**: RGB images (3 channels)
- **Normalization**: Pixel values in range [0, 1]
- **Preprocessing**: Images are automatically resized and normalized by the API

### Output
- **Shape**: `(3,)`
- **Activation**: Softmax
- **Classes**: `['animal', 'avatar', 'human']` (in this order)
- **Type**: Probability distribution summing to 1.0

## Training Data

The model should be trained on:
- **Human faces**: 51 diverse images from FairFace dataset (ages 18-70, multiple ethnicities)
- **Avatars**: 25 cartoon human face images from CartoonSet100k
- **Animals**: 25 cat and dog images

Training images are located in:
```
scripts/test_images/human/
scripts/test_images/avatar/
scripts/test_images/animal/
```

## Example Model Architecture

```python
from tensorflow import keras
from tensorflow.keras import layers

model = keras.Sequential([
    layers.Input(shape=(128, 128, 3)),
    
    # Convolutional layers
    layers.Conv2D(32, (3, 3), activation='relu'),
    layers.MaxPooling2D((2, 2)),
    
    layers.Conv2D(64, (3, 3), activation='relu'),
    layers.MaxPooling2D((2, 2)),
    
    layers.Conv2D(128, (3, 3), activation='relu'),
    layers.MaxPooling2D((2, 2)),
    
    # Dense layers
    layers.Flatten(),
    layers.Dense(128, activation='relu'),
    layers.Dropout(0.5),
    layers.Dense(3, activation='softmax')  # 3 classes
])

model.compile(
    optimizer='adam',
    loss='categorical_crossentropy',
    metrics=['accuracy']
)

# After training...
model.save('models/profile_classifier.keras')
```

## Verification

After placing your model file, verify it works:

1. Start the API server:
   ```bash
   python classifier_api.py
   ```

2. Check health endpoint:
   ```bash
   curl http://localhost:5001/api/health
   ```
   
   Should return `"model_loaded": true`

3. Run test suite:
   ```bash
   python test_classifier_api.py
   ```

## Placeholder

Until a trained model is provided, the API will use **mock predictions** for testing purposes.
