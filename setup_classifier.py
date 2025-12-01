#!/usr/bin/env python3
"""
Setup script for the Profile Picture Classifier API
Installs dependencies and verifies the environment
"""

import subprocess
import sys
import os
from pathlib import Path

def print_header(text):
    """Print a formatted header"""
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")

def print_step(step_num, text):
    """Print a step indicator"""
    print(f"\n[{step_num}] {text}")
    print("-" * 60)

def run_command(cmd, description):
    """Run a command and handle errors"""
    print(f"Running: {' '.join(cmd)}")
    try:
        subprocess.run(cmd, check=True)
        print(f"✓ {description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ {description} failed with error code {e.returncode}")
        return False
    except FileNotFoundError:
        print(f"✗ Command not found: {cmd[0]}")
        return False

def check_python_version():
    """Check if Python version is compatible"""
    version = sys.version_info
    print(f"Python version: {version.major}.{version.minor}.{version.micro}")
    
    if version.major < 3 or (version.major == 3 and version.minor < 9):
        print("✗ Python 3.9 or higher is required for TensorFlow 2.18.0")
        return False
    elif version.major == 3 and version.minor >= 13:
        print("⚠ Python 3.13+ detected. TensorFlow may have compatibility issues.")
        print("  Consider using Python 3.9-3.12 if you encounter problems.")
        return True
    else:
        print("✓ Python version is compatible")
        return True

def check_directories():
    """Check and create necessary directories"""
    base_dir = Path(__file__).parent
    models_dir = base_dir / "models"
    
    if not models_dir.exists():
        print(f"Creating models directory: {models_dir}")
        models_dir.mkdir(parents=True, exist_ok=True)
        print("✓ Models directory created")
    else:
        print(f"✓ Models directory exists: {models_dir}")
    
    # Check for model files
    model_files = list(models_dir.glob("*.h5")) + list(models_dir.glob("*.keras"))
    if model_files:
        print(f"✓ Found {len(model_files)} model file(s):")
        for f in model_files:
            print(f"  - {f.name}")
    else:
        print("⚠ No model files found in models/ directory")
        print("  The API will use mock predictions until a model is provided")
    
    return True

def install_dependencies():
    """Install dependencies from requirements file"""
    base_dir = Path(__file__).parent
    req_file = base_dir / "classifier_requirements.txt"
    
    if not req_file.exists():
        print(f"✗ Requirements file not found: {req_file}")
        return False
    
    print(f"Installing dependencies from {req_file.name}...")
    print("This may take several minutes (TensorFlow is large)...\n")
    
    return run_command(
        [sys.executable, "-m", "pip", "install", "-r", str(req_file)],
        "Dependency installation"
    )

def verify_imports():
    """Verify that key packages can be imported"""
    packages = [
        ("flask", "Flask"),
        ("flask_cors", "Flask-CORS"),
        ("PIL", "Pillow"),
        ("numpy", "NumPy"),
        ("tensorflow", "TensorFlow"),
    ]
    
    all_ok = True
    for module, name in packages:
        try:
            __import__(module)
            print(f"✓ {name} imported successfully")
        except ImportError as e:
            print(f"✗ Failed to import {name}: {e}")
            all_ok = False
    
    return all_ok

def main():
    """Main setup function"""
    print_header("Profile Picture Classifier API - Setup")
    
    # Step 1: Check Python version
    print_step(1, "Checking Python version")
    if not check_python_version():
        print("\n❌ Setup cannot continue with incompatible Python version")
        sys.exit(1)
    
    # Step 2: Check directories
    print_step(2, "Checking directory structure")
    if not check_directories():
        print("\n❌ Setup failed during directory check")
        sys.exit(1)
    
    # Step 3: Install dependencies
    print_step(3, "Installing dependencies")
    if not install_dependencies():
        print("\n❌ Setup failed during dependency installation")
        sys.exit(1)
    
    # Step 4: Verify imports
    print_step(4, "Verifying package imports")
    if not verify_imports():
        print("\n❌ Setup completed but some packages cannot be imported")
        print("Try running: pip install -r classifier_requirements.txt")
        sys.exit(1)
    
    # Success
    print_header("Setup Complete!")
    print("✓ All dependencies installed")
    print("✓ Environment verified")
    print("\nNext steps:")
    print("  1. Place your trained model in the models/ directory")
    print("     (models/profile_classifier.keras or models/profile_classifier.h5)")
    print("\n  2. Start the API server:")
    print("     python classifier_api.py")
    print("\n  3. Test the API:")
    print("     python test_classifier_api.py")
    print("\n  4. Check the documentation:")
    print("     See CLASSIFIER_API.md for full API documentation")
    print("\n" + "="*60 + "\n")

if __name__ == "__main__":
    main()
