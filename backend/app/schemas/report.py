from pydantic import BaseModel, Field
from typing import Optional, Any
from enum import Enum


class ReportKind(str, Enum):
    WRONG_WORKOUT_TYPE = "wrong_workout_type"
    WRONG_INTERVALS = "wrong_intervals"
    OTHER = "other"


class Platform(str, Enum):
    IOS = "ios"
    ANDROID = "android"
    WEB = "web"


class TimerReportRequest(BaseModel):
    report_kind: ReportKind = Field(..., description="Category of the parsing problem")
    message: Optional[str] = Field(
        None, max_length=1000, description="Optional free-text details"
    )
    original_parsed: dict[str, Any] = Field(
        ..., description="The original AI-parsed timer config"
    )
    edited_config: Optional[dict[str, Any]] = Field(
        None, description="The user-corrected timer config"
    )
    app_version: str = Field(..., min_length=1, description="App version string")
    platform: Platform = Field(..., description="Platform: ios, android, or web")


class TimerReportResponse(BaseModel):
    id: str = Field(..., description="UUID of the created report")
    message: str = Field(default="Report submitted successfully")
