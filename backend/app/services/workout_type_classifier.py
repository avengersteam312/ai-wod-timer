import re
from typing import Optional
from dataclasses import dataclass, field
from app.schemas.workout import WorkoutType


@dataclass
class WorkoutTypeKeywords:
    """Configuration for workout type keywords."""

    keywords: list[str] = field(default_factory=list)
    patterns: list[str] = field(default_factory=list)  # Regex patterns
    priority: int = 0  # Higher priority wins in case of multiple matches


class WorkoutTypeClassifier:
    """
    Classifies workout text into workout types based on configurable keywords.

    Usage:
        classifier = WorkoutTypeClassifier()
        workout_type = classifier.classify("AMRAP 20 minutes: 10 burpees, 15 squats")
        # Returns: WorkoutType.AMRAP

        # Add custom keywords
        classifier.add_keywords(WorkoutType.AMRAP, ["as many as possible"])

        # Replace all keywords for a type
        classifier.set_keywords(WorkoutType.TABATA, ["tabata", "20/10"])
    """

    def __init__(self):
        self._keyword_config: dict[WorkoutType, WorkoutTypeKeywords] = {}
        self._setup_default_keywords()

    def _setup_default_keywords(self) -> None:
        """Setup default keywords for each workout type."""

        # AMRAP - As Many Rounds/Reps As Possible
        self._keyword_config[WorkoutType.AMRAP] = WorkoutTypeKeywords(
            keywords=[
                "amrap",
                "as many rounds as possible",
                "as many reps as possible",
                "max rounds",
                "max reps",
            ],
            patterns=[
                r"amrap\s*\d+",  # AMRAP 20, AMRAP20
                r"\d+\s*min(?:ute)?s?\s+amrap",  # 20 min AMRAP
            ],
            priority=10,
        )

        # EMOM - Every Minute On the Minute
        self._keyword_config[WorkoutType.EMOM] = WorkoutTypeKeywords(
            keywords=[
                "emom",
                "every minute on the minute",
                "e2mom",
                "every 2 minutes",
                "e3mom",
                "every 3 minutes",
                "e90s",
                "every 90 seconds",
                "every 90s",
                "otm",  # On The Minute
            ],
            patterns=[
                r"e\d+mom",  # E2MOM, E3MOM, etc.
                r"every\s+\d+\s*min",  # every 2 min
                r"every\s+\d+\s*sec",  # every 90 sec
            ],
            priority=10,
        )

        # FOR TIME
        self._keyword_config[WorkoutType.FOR_TIME] = WorkoutTypeKeywords(
            keywords=[
                "for time",
                "ft",
                "time cap",
                "complete as fast as possible",
                "rft",  # Rounds For Time
                "afap",  # As Fast As Possible
            ],
            patterns=[
                r"for\s+time",
                r"\d+\s+rounds?\s+for\s+time",  # 5 rounds for time
                r"time\s*cap\s*:?\s*\d+",  # time cap: 20
            ],
            priority=8,
        )

        # TABATA - 20s work / 10s rest
        self._keyword_config[WorkoutType.TABATA] = WorkoutTypeKeywords(
            keywords=[
                "tabata",
                "20/10",
                "20 on 10 off",
                "20 seconds on 10 seconds off",
                "tabata intervals",
                "tabata style",
            ],
            patterns=[
                r"tabata",
                r"20\s*/\s*10",  # 20/10
                r"20s?\s+on\s+10s?\s+off",  # 20s on 10s off
            ],
            priority=10,
        )

        # INTERVALS - Custom work/rest intervals
        self._keyword_config[WorkoutType.INTERVALS] = WorkoutTypeKeywords(
            keywords=[
                "intervals",
                "interval training",
                "work/rest",
                "on/off",
                "hiit",
                "high intensity interval",
                "circuit",
                "rounds of",
            ],
            patterns=[
                r"\d+s?\s*/\s*\d+s?",  # 30/15, 40s/20s (but not 20/10 which is tabata)
                r"\d+\s+seconds?\s+on\s+\d+\s+seconds?\s+off",
                r"\d+\s+on\s+\d+\s+off",
                r"work\s*:\s*\d+.*rest\s*:\s*\d+",  # work: 30 rest: 15
            ],
            priority=5,  # Lower priority than tabata
        )

        # STOPWATCH - Open-ended timing
        self._keyword_config[WorkoutType.STOPWATCH] = WorkoutTypeKeywords(
            keywords=[
                "stopwatch",
                "count up",
                "open timer",
                "no time limit",
                "untimed",
                "track time",
                "record time",
            ],
            patterns=[
                r"stop\s*watch",
                r"count\s+up",
            ],
            priority=3,
        )

    def classify(self, workout_text: str) -> WorkoutType:
        """
        Classify workout text into a workout type based on keywords.

        Args:
            workout_text: The raw workout description text.

        Returns:
            WorkoutType enum value. Returns CUSTOM if no match found.
        """
        text_lower = workout_text.lower().strip()

        matches: list[tuple[WorkoutType, int]] = []

        for workout_type, config in self._keyword_config.items():
            if self._matches_type(text_lower, config):
                matches.append((workout_type, config.priority))

        if not matches:
            return WorkoutType.CUSTOM

        # Sort by priority (highest first) and return the best match
        matches.sort(key=lambda x: x[1], reverse=True)
        return matches[0][0]

    def _matches_type(self, text: str, config: WorkoutTypeKeywords) -> bool:
        """Check if text matches any keywords or patterns for a workout type."""
        # Check exact keywords
        for keyword in config.keywords:
            if keyword.lower() in text:
                return True

        # Check regex patterns
        for pattern in config.patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return True

        return False

    def get_keywords(self, workout_type: WorkoutType) -> WorkoutTypeKeywords:
        """Get the keyword configuration for a workout type."""
        return self._keyword_config.get(workout_type, WorkoutTypeKeywords())

    def set_keywords(
        self,
        workout_type: WorkoutType,
        keywords: list[str],
        patterns: Optional[list[str]] = None,
        priority: Optional[int] = None,
    ) -> None:
        """
        Replace all keywords for a workout type.

        Args:
            workout_type: The workout type to configure.
            keywords: List of keywords to match.
            patterns: Optional list of regex patterns.
            priority: Optional priority (higher wins).
        """
        existing = self._keyword_config.get(workout_type, WorkoutTypeKeywords())
        self._keyword_config[workout_type] = WorkoutTypeKeywords(
            keywords=keywords,
            patterns=patterns if patterns is not None else existing.patterns,
            priority=priority if priority is not None else existing.priority,
        )

    def add_keywords(
        self,
        workout_type: WorkoutType,
        keywords: list[str],
        patterns: Optional[list[str]] = None,
    ) -> None:
        """
        Add additional keywords to a workout type.

        Args:
            workout_type: The workout type to configure.
            keywords: List of keywords to add.
            patterns: Optional list of regex patterns to add.
        """
        existing = self._keyword_config.get(workout_type, WorkoutTypeKeywords())
        new_keywords = list(set(existing.keywords + keywords))
        new_patterns = list(set(existing.patterns + (patterns or [])))

        self._keyword_config[workout_type] = WorkoutTypeKeywords(
            keywords=new_keywords,
            patterns=new_patterns,
            priority=existing.priority,
        )

    def remove_keywords(
        self,
        workout_type: WorkoutType,
        keywords: list[str],
        patterns: Optional[list[str]] = None,
    ) -> None:
        """
        Remove keywords from a workout type.

        Args:
            workout_type: The workout type to configure.
            keywords: List of keywords to remove.
            patterns: Optional list of regex patterns to remove.
        """
        existing = self._keyword_config.get(workout_type, WorkoutTypeKeywords())
        new_keywords = [k for k in existing.keywords if k not in keywords]
        new_patterns = [p for p in existing.patterns if p not in (patterns or [])]

        self._keyword_config[workout_type] = WorkoutTypeKeywords(
            keywords=new_keywords,
            patterns=new_patterns,
            priority=existing.priority,
        )

    def get_all_config(self) -> dict[WorkoutType, WorkoutTypeKeywords]:
        """Get the full keyword configuration for all workout types."""
        return self._keyword_config.copy()


# Singleton instance
workout_type_classifier = WorkoutTypeClassifier()
