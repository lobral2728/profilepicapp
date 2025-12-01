"""
Example CNN Model Training Script for Profile Picture Classification

This is a template/example script showing how to train a CNN model
for classifying profile pictures into: animal, avatar, or human

NOTE: This is just a starting point. You'll need to adjust:
- Hyperparameters (epochs, batch_size, learning_rate, etc.)
- Model architecture (layers, filters, etc.)
- Data augmentation settings
- Train/validation split strategy

Requirements:
- TensorFlow 2.x
- Training images in: scripts/test_images/human/, avatar/, animal/
"""

import os
import numpy as np
from pathlib import Path
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.preprocessing.image import ImageDataGenerator

# Configuration
IMG_SIZE = (128, 128)
BATCH_SIZE = 16
EPOCHS = 50
LEARNING_RATE = 0.001
VALIDATION_SPLIT = 0.2

# Paths
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "scripts" / "test_images"
MODEL_OUTPUT = BASE_DIR / "models" / "profile_classifier.keras"

# Class mapping (must match classifier_api.py)
CLASS_NAMES = ['animal', 'avatar', 'human']


def create_model(input_shape=(128, 128, 3), num_classes=3):
    """
    Create a CNN model for image classification
    
    This is a simple example architecture. Consider:
    - Using pre-trained models (ResNet, MobileNet, EfficientNet)
    - Adding batch normalization
    - Experimenting with different architectures
    - Using regularization techniques
    """
    model = keras.Sequential([
        layers.Input(shape=input_shape),
        
        # First convolutional block
        layers.Conv2D(32, (3, 3), activation='relu', padding='same'),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        
        # Second convolutional block
        layers.Conv2D(64, (3, 3), activation='relu', padding='same'),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        
        # Third convolutional block
        layers.Conv2D(128, (3, 3), activation='relu', padding='same'),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        
        # Fourth convolutional block
        layers.Conv2D(256, (3, 3), activation='relu', padding='same'),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),
        
        # Flatten and dense layers
        layers.Flatten(),
        layers.Dense(512, activation='relu'),
        layers.Dropout(0.5),
        layers.Dense(num_classes, activation='softmax')
    ])
    
    return model


def create_data_generators():
    """
    Create data generators with augmentation
    
    Augmentation helps prevent overfitting and improves generalization.
    Adjust these settings based on your data characteristics.
    """
    # Training data augmentation
    train_datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=20,
        width_shift_range=0.2,
        height_shift_range=0.2,
        horizontal_flip=True,
        zoom_range=0.2,
        validation_split=VALIDATION_SPLIT
    )
    
    # Validation data (no augmentation, just rescaling)
    val_datagen = ImageDataGenerator(
        rescale=1./255,
        validation_split=VALIDATION_SPLIT
    )
    
    # Training generator
    train_generator = train_datagen.flow_from_directory(
        DATA_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        classes=CLASS_NAMES,
        subset='training',
        shuffle=True
    )
    
    # Validation generator
    val_generator = val_datagen.flow_from_directory(
        DATA_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        classes=CLASS_NAMES,
        subset='validation',
        shuffle=False
    )
    
    return train_generator, val_generator


def main():
    """Main training function"""
    print("=" * 60)
    print("Profile Picture Classifier - Model Training")
    print("=" * 60)
    
    # Check if data directory exists
    if not DATA_DIR.exists():
        print(f"ERROR: Data directory not found: {DATA_DIR}")
        print("Please ensure images are in:")
        print(f"  {DATA_DIR / 'animal'}")
        print(f"  {DATA_DIR / 'avatar'}")
        print(f"  {DATA_DIR / 'human'}")
        return
    
    # Count images per class
    print("\nDataset Summary:")
    print("-" * 60)
    for class_name in CLASS_NAMES:
        class_dir = DATA_DIR / class_name
        if class_dir.exists():
            count = len(list(class_dir.glob("*.jpg"))) + len(list(class_dir.glob("*.png")))
            print(f"  {class_name:10s}: {count:3d} images")
        else:
            print(f"  {class_name:10s}: MISSING DIRECTORY!")
    
    # Create data generators
    print("\nCreating data generators...")
    train_gen, val_gen = create_data_generators()
    
    print(f"Training samples: {train_gen.samples}")
    print(f"Validation samples: {val_gen.samples}")
    
    # Create model
    print("\nCreating model...")
    model = create_model()
    
    # Print model summary
    print("\nModel Architecture:")
    print("-" * 60)
    model.summary()
    
    # Compile model
    print("\nCompiling model...")
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=LEARNING_RATE),
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Callbacks
    callbacks = [
        # Save best model
        keras.callbacks.ModelCheckpoint(
            MODEL_OUTPUT,
            monitor='val_accuracy',
            save_best_only=True,
            mode='max',
            verbose=1
        ),
        # Early stopping
        keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=10,
            restore_best_weights=True,
            verbose=1
        ),
        # Reduce learning rate on plateau
        keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-7,
            verbose=1
        )
    ]
    
    # Train model
    print(f"\nTraining for {EPOCHS} epochs...")
    print("=" * 60)
    
    history = model.fit(
        train_gen,
        validation_data=val_gen,
        epochs=EPOCHS,
        callbacks=callbacks,
        verbose=1
    )
    
    # Save final model
    print("\n" + "=" * 60)
    print(f"Training complete!")
    print(f"Model saved to: {MODEL_OUTPUT}")
    
    # Print final metrics
    final_train_acc = history.history['accuracy'][-1]
    final_val_acc = history.history['val_accuracy'][-1]
    final_train_loss = history.history['loss'][-1]
    final_val_loss = history.history['val_loss'][-1]
    
    print(f"\nFinal Metrics:")
    print(f"  Training Accuracy:   {final_train_acc:.4f}")
    print(f"  Validation Accuracy: {final_val_acc:.4f}")
    print(f"  Training Loss:       {final_train_loss:.4f}")
    print(f"  Validation Loss:     {final_val_loss:.4f}")
    
    print("\nNext steps:")
    print("  1. Test the model: python test_classifier_api.py")
    print("  2. Start the API: python classifier_api.py")
    print("=" * 60)


if __name__ == "__main__":
    main()
