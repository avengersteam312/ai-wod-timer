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
                "amrap",  # Matches: amrap, amrap20, etc.
            ],
            patterns=[
                r"amrap\s*\d+",  # AMRAP 20, AMRAP20
                r"\d+\s*min(?:ute)?s?\s+amrap",  # 20 min AMRAP
                r"as\s+many\s+(rounds?|reps?)\s+as\s+possible",  # as many rounds as possible
                r"max\s+(rounds?|reps?)",  # max rounds, max reps
            ],
            priority=10,
        )

        # EMOM - Every Minute On the Minute
        self._keyword_config[WorkoutType.EMOM] = WorkoutTypeKeywords(
            keywords=[
                "emom",  # Matches: emom, e2mom, e3mom via pattern
                "otm",  # On The Minute
            ],
            patterns=[
                r"e\d*mom",  # EMOM, E2MOM, E3MOM, etc.
                r"every\s+\d*\s*min",  # every min, every 2 min
                r"every\s+\d+\s*sec",  # every 90 sec
                r"every\s+minute",  # every minute on the minute
            ],
            priority=10,
        )

        # FOR TIME
        self._keyword_config[WorkoutType.FOR_TIME] = WorkoutTypeKeywords(
            keywords=[
                "for time",
                "rft",  # Rounds For Time
                "afap",  # As Fast As Possible
            ],
            patterns=[
                r"for\s+time",
                r"\d+\s+rounds?\s+for\s+time",  # 5 rounds for time
                r"time\s*cap",  # time cap, timecap
                r"as\s+fast\s+as\s+possible",
            ],
            priority=8,
        )

        # TABATA - 20s work / 10s rest
        self._keyword_config[WorkoutType.TABATA] = WorkoutTypeKeywords(
            keywords=[
                "tabata",  # Matches: tabata, tabata intervals, tabata style, etc.
            ],
            patterns=[
                r"20\s*/\s*10",  # 20/10
                r"20s?\s+on\s+10s?\s+off",  # 20s on 10s off
                r"20\s+seconds?\s+on\s+10\s+seconds?\s+off",  # 20 seconds on 10 seconds off
            ],
            priority=10,
        )

        # INTERVALS - Custom work/rest intervals
        self._keyword_config[WorkoutType.INTERVALS] = WorkoutTypeKeywords(
            keywords=[
                "interval",  # Matches: interval, intervals, interval training, interval wod, etc.
                "hiit",  # High Intensity Interval Training
                "circuit",
            ],
            patterns=[
                r"\d+s?\s*/\s*\d+s?",  # 30/15, 40s/20s (but not 20/10 which is tabata)
                r"\d+\s+seconds?\s+on\s+\d+\s+seconds?\s+off",
                r"\d+\s+on\s+\d+\s+off",
                r"work\s*[:/]\s*\d+.*rest\s*[:/]\s*\d+",  # work: 30 rest: 15 or work/30 rest/15
                r"\d+\s+seconds?\s+work\s*/?\s*\d+\s+seconds?\s+rest",  # 40 seconds work / 20 seconds rest
                r"\d+s?\s+work\s*/?\s*\d+s?\s+rest",  # 40s work / 20s rest
                r"on\s*/\s*off",  # on/off
                r"work\s*/\s*rest",  # work/rest
            ],
            priority=9,  # Higher priority than FOR_TIME (8) to properly detect interval workouts
        )

        # STOPWATCH - Open-ended timing
        self._keyword_config[WorkoutType.STOPWATCH] = WorkoutTypeKeywords(
            keywords=[
                "stopwatch",
                "untimed",
            ],
            patterns=[
                r"stop\s*watch",
                r"count\s+up",
                r"open\s+timer",
                r"no\s+time\s+limit",
                r"track\s+time",
                r"record\s+time",
            ],
            priority=3,
        )

    def classify(self, workout_text: str) -> WorkoutType:
        """
        Classify workout text into a workout type based on keywords.

        Uses a scoring system that combines base priority with match count
        to better distinguish between workout types with overlapping patterns.

        Args:
            workout_text: The raw workout description text.

        Returns:
            WorkoutType enum value. Returns CUSTOM if no match found.
        """
        text_lower = workout_text.lower().strip()

        matches: list[tuple[WorkoutType, float]] = []

        for workout_type, config in self._keyword_config.items():
            score = self._calculate_match_score(text_lower, config)
            if score > 0:
                matches.append((workout_type, score))

        if not matches:
            return WorkoutType.CUSTOM

        # Sort by score (highest first) and return the best match
        matches.sort(key=lambda x: x[1], reverse=True)
        return matches[0][0]

    def _calculate_match_score(self, text: str, config: WorkoutTypeKeywords) -> float:
        """
        Calculate a weighted score for how well text matches a workout type.

        Score = base_priority + (keyword_matches * 2) + (pattern_matches * 3)

        This ensures types with more matching evidence score higher,
        even if another type has a higher base priority.
        """
        keyword_matches = 0
        pattern_matches = 0

        # Count keyword matches
        for keyword in config.keywords:
            if keyword.lower() in text:
                keyword_matches += 1

        # Count pattern matches
        for pattern in config.patterns:
            if re.search(pattern, text, re.IGNORECASE):
                pattern_matches += 1

        # No matches = score of 0
        if keyword_matches == 0 and pattern_matches == 0:
            return 0

        # Calculate weighted score
        # Base priority provides the foundation
        # Each keyword match adds 2 points
        # Each pattern match adds 3 points (patterns are more specific)
        score = config.priority + (keyword_matches * 2) + (pattern_matches * 3)

        return score

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
