"""
User model for Postgres database.
Links Firebase UID to our database records.

Note: This model is defined but not yet integrated with SQLAlchemy Base.
When database integration is needed, create a base.py file with:
    from sqlalchemy.orm import declarative_base
    Base = declarative_base()
Then update this model to inherit from Base.
"""

from sqlalchemy import Column, String, DateTime, Boolean
from sqlalchemy.sql import func
from typing import Optional


class User:
    """
    User model that links Firebase authentication to our Postgres database.

    We store:
    - Firebase UID (primary key, unique identifier from Firebase)
    - Email (from Firebase)
    - Created/updated timestamps
    - Any additional user preferences/data we want to store

    Note: Firebase handles authentication, we just store a reference here.
    """

    __tablename__ = "users"

    # Firebase UID is our primary key
    id: str = Column(String, primary_key=True)  # Firebase UID
    email: str = Column(String, unique=True, nullable=False, index=True)
    email_verified: bool = Column(Boolean, default=False)
    display_name: Optional[str] = Column(String, nullable=True)
    photo_url: Optional[str] = Column(String, nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self) -> str:
        return f"<User(id={self.id}, email={self.email})>"
