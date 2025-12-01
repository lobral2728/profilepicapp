"""
Test client for the Profile Picture Classifier API.
Demonstrates how to use the classification endpoint.
"""
import requests
import json
import os
from pathlib import Path


def test_health_check(api_url):
    """Test the health check endpoint."""
    print("\n" + "=" * 60)
    print("Testing Health Check...")
    print("=" * 60)
    
    response = requests.get(f"{api_url}/api/health")
    print(f"Status Code: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200


def test_classify_file(api_url, image_path):
    """Test classification with a local file."""
    print("\n" + "=" * 60)
    print(f"Testing File Classification: {image_path}")
    print("=" * 60)
    
    if not os.path.exists(image_path):
        print(f"Error: File not found: {image_path}")
        return False
    
    with open(image_path, 'rb') as f:
        files = {'image': f}
        response = requests.post(f"{api_url}/api/classify", files=files)
    
    print(f"Status Code: {response.status_code}")
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    
    if result.get('success'):
        print(f"\n✓ Prediction: {result['predicted_class']} (confidence: {result['confidence']:.2%})")
        print(f"  Probabilities:")
        for category, prob in result['probabilities'].items():
            bar = "█" * int(prob * 50)
            print(f"    {category:10s}: {bar:50s} {prob:.2%}")
    
    return response.status_code == 200


def test_classify_url(api_url, image_url):
    """Test classification with an image URL."""
    print("\n" + "=" * 60)
    print(f"Testing URL Classification")
    print("=" * 60)
    print(f"Image URL: {image_url}")
    
    data = {'image_url': image_url}
    response = requests.post(
        f"{api_url}/api/classify/url",
        json=data,
        headers={'Content-Type': 'application/json'}
    )
    
    print(f"Status Code: {response.status_code}")
    result = response.json()
    print(f"Response: {json.dumps(result, indent=2)}")
    
    if result.get('success'):
        print(f"\n✓ Prediction: {result['predicted_class']} (confidence: {result['confidence']:.2%})")
    
    return response.status_code == 200


def test_multiple_images(api_url, image_dir):
    """Test classification with multiple images from a directory."""
    print("\n" + "=" * 60)
    print(f"Testing Multiple Images from: {image_dir}")
    print("=" * 60)
    
    if not os.path.exists(image_dir):
        print(f"Error: Directory not found: {image_dir}")
        return False
    
    # Find image files
    image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif'}
    image_files = []
    
    for ext in image_extensions:
        image_files.extend(Path(image_dir).glob(f"*{ext}"))
        image_files.extend(Path(image_dir).glob(f"*{ext.upper()}"))
    
    if not image_files:
        print(f"No image files found in {image_dir}")
        return False
    
    # Limit to first 10 images for testing
    image_files = sorted(image_files)[:10]
    
    print(f"Found {len(image_files)} images to test\n")
    
    results = []
    for img_path in image_files:
        with open(img_path, 'rb') as f:
            files = {'image': f}
            response = requests.post(f"{api_url}/api/classify", files=files)
        
        if response.status_code == 200:
            result = response.json()
            if result.get('success'):
                results.append({
                    'filename': img_path.name,
                    'prediction': result['predicted_class'],
                    'confidence': result['confidence']
                })
                print(f"✓ {img_path.name:30s} -> {result['predicted_class']:8s} ({result['confidence']:.2%})")
    
    # Summary
    if results:
        print(f"\n--- Summary ---")
        print(f"Total tested: {len(results)}")
        
        from collections import Counter
        predictions = Counter(r['prediction'] for r in results)
        for category, count in predictions.most_common():
            print(f"  {category}: {count}")
    
    return True


def main():
    """Main test function."""
    # API URL - change this if your API is running on a different host/port
    API_URL = "http://localhost:5001"
    
    print("=" * 60)
    print("Profile Picture Classifier API - Test Client")
    print("=" * 60)
    print(f"API URL: {API_URL}")
    
    # Test 1: Health check
    test_health_check(API_URL)
    
    # Test 2: Classify a local file (if available)
    test_image_paths = [
        "scripts/test_images/human/human_001.jpg",
        "scripts/test_images/avatar/avatar_01.jpg",
        "scripts/test_images/animal/animal_01.jpg",
    ]
    
    for image_path in test_image_paths:
        if os.path.exists(image_path):
            test_classify_file(API_URL, image_path)
            break
    
    # Test 3: Classify from URL (example from Azure Blob Storage)
    # Uncomment to test with a real URL
    # test_classify_url(API_URL, "https://profilepicsto7826.blob.core.windows.net/profile-photos/profile_human_001.jpg")
    
    # Test 4: Test multiple images from a directory
    test_dirs = [
        "scripts/test_images/human",
        "scripts/test_images/avatar",
        "scripts/test_images/animal",
    ]
    
    for test_dir in test_dirs:
        if os.path.exists(test_dir):
            test_multiple_images(API_URL, test_dir)
            break
    
    print("\n" + "=" * 60)
    print("Testing Complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()
