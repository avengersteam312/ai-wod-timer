"""
Firebase Admin SDK service for token verification.
This service verifies Firebase ID tokens sent from the frontend.
"""
import os
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, auth
from app.config import settings
import logging

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
_firebase_app = None


def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    global _firebase_app
    
    if _firebase_app is None:
        try:
            # Try to use credentials file if provided
            if settings.FIREBASE_CREDENTIALS_PATH:
                cred_path = settings.FIREBASE_CREDENTIALS_PATH
                # Handle relative paths
                if not os.path.isabs(cred_path):
                    cred_path = str(Path.cwd() / cred_path)
                
                if not os.path.exists(cred_path):
                    raise FileNotFoundError(
                        f"Firebase credentials file not found: {cred_path}. "
                        f"Please download it from Firebase Console and save it to backend/"
                    )
                
                cred = credentials.Certificate(cred_path)
                _firebase_app = firebase_admin.initialize_app(cred)
            else:
                # Use default credentials (works with GOOGLE_APPLICATION_CREDENTIALS env var)
                # Or initialize with project ID (for development/testing)
                try:
                    _firebase_app = firebase_admin.initialize_app(
                        options={'projectId': settings.FIREBASE_PROJECT_ID}
                    )
                except ValueError:
                    # App already initialized
                    _firebase_app = firebase_admin.get_app()
            
            logger.info("Firebase Admin SDK initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
            raise
    
    return _firebase_app


def verify_firebase_token(token: str) -> dict:
    """
    Verify a Firebase ID token and return the decoded token.
    
    Args:
        token: Firebase ID token string
        
    Returns:
        Decoded token containing user information (uid, email, etc.)
        
    Raises:
        ValueError: If token is invalid or expired
    """
    if not token or not isinstance(token, str):
        raise ValueError("Token is required and must be a string")
    
    try:
        # Ensure Firebase is initialized
        initialize_firebase()
        
        # Verify the token
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except ValueError as e:
        # Re-raise ValueError as-is (these are expected validation errors)
        logger.warning(f"Token verification failed: {e}")
        raise
    except Exception as e:
        # Log unexpected errors but raise as ValueError for consistent error handling
        logger.error(f"Unexpected error during token verification: {e}", exc_info=True)
        raise ValueError("Token verification failed")


def get_user_by_uid(uid: str) -> dict:
    """
    Get user information from Firebase by UID.
    
    Args:
        uid: Firebase user UID
        
    Returns:
        User record from Firebase
    """
    try:
        initialize_firebase()
        user_record = auth.get_user(uid)
        return {
            'uid': user_record.uid,
            'email': user_record.email,
            'email_verified': user_record.email_verified,
            'display_name': user_record.display_name,
            'photo_url': user_record.photo_url,
        }
    except Exception as e:
        logger.error(f"Failed to get user {uid}: {e}")
        raise
