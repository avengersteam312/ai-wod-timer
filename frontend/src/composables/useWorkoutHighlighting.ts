import { computed, type Ref } from 'vue'

export interface HighlightSegment {
  text: string
  type: 'keyword' | 'time' | 'normal'
  start: number
  end: number
}

// Workout type keywords to highlight (case-insensitive matching)
const WORKOUT_KEYWORDS = [
  { pattern: /\bamrap\b/gi, text: 'AMRAP' },
  { pattern: /\bemom\b/gi, text: 'EMOM' },
  { pattern: /\be\d+mom\b/gi, text: 'E2MOM/E3MOM' }, // E2MOM, E3MOM, etc.
  { pattern: /\btabata\b/gi, text: 'Tabata' },
  { pattern: /\bfor\s+time\b/gi, text: 'For Time' },
  { pattern: /\brft\b/gi, text: 'RFT' },
  { pattern: /\bafap\b/gi, text: 'AFAP' },
  { pattern: /\botm\b/gi, text: 'OTM' },
  { pattern: /\binterval(?:s)?\b/gi, text: 'Interval(s)' },
  { pattern: /\bhiit\b/gi, text: 'HIIT' },
  { pattern: /\bcircuit\b/gi, text: 'Circuit' },
  { pattern: /\bstopwatch\b/gi, text: 'Stopwatch' },
  { pattern: /\bas\s+many\s+(?:rounds?|reps?)\s+as\s+possible\b/gi, text: 'As Many Rounds/Reps As Possible' },
  { pattern: /\bmax\s+(?:rounds?|reps?)\b/gi, text: 'Max Rounds/Reps' },
  { pattern: /\bevery\s+minute\b/gi, text: 'Every Minute' },
  { pattern: /\bon\s+the\s+minute\b/gi, text: 'On The Minute' },
  { pattern: /\btime\s+cap\b/gi, text: 'Time Cap' },
  { pattern: /\bwork\s*\/\s*rest\b/gi, text: 'Work/Rest' },
]

// Time patterns (numbers followed by time units)
const TIME_PATTERNS = [
  /\d+\s*(?:min|minute|minutes|m)(?!\w)/gi, // minutes
  /\d+\s*(?:sec|second|seconds|s)(?!\w)/gi, // seconds
  /\d+\s*(?:hour|hours|hr|hrs|h)(?!\w)/gi, // hours
  /\d+:\d{2}(?::\d{2})?/g, // MM:SS or HH:MM:SS
  /\d+\s*\/\s*\d+\s*(?:sec|second|seconds|s|min|minute|minutes|m)/gi, // intervals like 20/10
]

export function useWorkoutHighlighting(text: Ref<string>) {
  const highlights = computed(() => {
    if (!text.value) return []

    const segments: HighlightSegment[] = []
    let lastIndex = 0

    // Find all keyword matches
    const keywordMatches: Array<{ start: number; end: number; text: string }> = []

    WORKOUT_KEYWORDS.forEach((keywordConfig) => {
      const regex = keywordConfig.pattern
      // Reset regex lastIndex to avoid issues with global regex
      regex.lastIndex = 0
      let match: RegExpExecArray | null
      while ((match = regex.exec(text.value)) !== null) {
        keywordMatches.push({
          start: match.index,
          end: match.index + match[0].length,
          text: match[0],
        })
      }
    })

    // Find all time matches
    const timeMatches: Array<{ start: number; end: number; text: string }> = []

    TIME_PATTERNS.forEach((pattern) => {
      pattern.lastIndex = 0
      let match: RegExpExecArray | null
      while ((match = pattern.exec(text.value)) !== null) {
        // Check if this time pattern overlaps with a keyword match
        const overlapsKeyword = keywordMatches.some(
          (km) =>
            (match!.index >= km.start && match!.index < km.end) ||
            (match!.index + match![0].length > km.start &&
              match!.index + match![0].length <= km.end) ||
            (match!.index <= km.start && match!.index + match![0].length >= km.end)
        )

        if (!overlapsKeyword) {
          timeMatches.push({
            start: match.index,
            end: match.index + match[0].length,
            text: match[0],
          })
        }
      }
    })

    // Combine and sort all matches, removing duplicates and overlaps
    const allMatches = [
      ...keywordMatches.map((m) => ({ ...m, type: 'keyword' as const })),
      ...timeMatches.map((m) => ({ ...m, type: 'time' as const })),
    ]
      .sort((a, b) => {
        // Sort by start position, then by end position
        if (a.start !== b.start) return a.start - b.start
        return a.end - b.end
      })
      .filter((match, index, arr) => {
        // Remove duplicates (same start and end)
        if (index > 0) {
          const prev = arr[index - 1]!
          if (prev.start === match.start && prev.end === match.end) {
            return false
          }
        }
        return true
      })

    // If no matches, return single normal segment
    if (allMatches.length === 0) {
      return [{ text: text.value, type: 'normal' as const, start: 0, end: text.value.length }]
    }

    // Build segments, ensuring no overlaps
    allMatches.forEach((match) => {
      // Skip if this match is completely within a previous match
      if (match.start < lastIndex) {
        // If it overlaps, adjust the start
        if (match.end > lastIndex) {
          // Partial overlap - skip the overlapping part
          match.start = lastIndex
        } else {
          // Completely overlapped, skip this match
          return
        }
      }

      // Add normal segment before this match
      if (match.start > lastIndex) {
        segments.push({
          text: text.value.substring(lastIndex, match.start),
          type: 'normal',
          start: lastIndex,
          end: match.start,
        })
      }

      // Add highlighted segment
      segments.push({
        text: match.text,
        type: match.type,
        start: match.start,
        end: match.end,
      })

      lastIndex = Math.max(lastIndex, match.end)
    })

    // Add remaining normal text
    if (lastIndex < text.value.length) {
      segments.push({
        text: text.value.substring(lastIndex),
        type: 'normal',
        start: lastIndex,
        end: text.value.length,
      })
    }

    return segments
  })

  return { highlights }
}
