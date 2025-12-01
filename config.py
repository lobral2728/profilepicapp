"""
Configuration settings for the application.
"""
import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    """Base configuration."""
    SECRET_KEY = os.getenv('FLASK_SECRET_KEY', 'dev-secret-key')
    CLIENT_ID = os.getenv('CLIENT_ID')
    CLIENT_SECRET = os.getenv('CLIENT_SECRET')
    TENANT_ID = os.getenv('TENANT_ID')
    REDIRECT_URI = os.getenv('REDIRECT_URI', 'http://localhost:5000/auth/callback')


class DevelopmentConfig(Config):
    """Development configuration."""
    DEBUG = True


class ProductionConfig(Config):
    """Production configuration."""
    DEBUG = False
    # Use environment variable or generate a secure secret key
    SECRET_KEY = os.getenv('FLASK_SECRET_KEY')
