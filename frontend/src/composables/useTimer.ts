import { ref, onUnmounted } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { useAudio } from './useAudio'

export function useTimer() {
  const timerStore = useTimerStore()
  const { state, currentTime, config, prepTime, prepDuration, intervalTime, currentInterval, currentIntervalIndex, totalIntervals, isIntervalBased } = storeToRefs(timerStore)
  const { playBeep, playCountdown, speak } = useAudio()

  let intervalId: number | null = null
  const lastCueTime = ref(-1)
  const lastIntervalCue = ref(-1)

  const startTimer = () => {
    if (intervalId) return

    timerStore.start()
    intervalId = window.setInterval(() => {
      if (state.value === TimerState.PREPARING) {
        handlePreparation()
      } else if (state.value === TimerState.RUNNING) {
        handleRunning()
      }
    }, 1000)
  }

  const handlePreparation = () => {
    timerStore.incrementPrepTime()

    const remaining = prepDuration.value - prepTime.value

    // Announce countdown: "ten seconds", 3, 2, 1
    if (remaining === 10) {
      speak('ten seconds')
      playCountdown()
    } else if (remaining > 0 && remaining <= 3) {
      speak(remaining.toString())
      playCountdown()
    }

    // Preparation complete, start workout
    if (prepTime.value >= prepDuration.value) {
      speak('GO!')
      playBeep()
      timerStore.startWorkout()
    }
  }

  const handleRunning = () => {
    timerStore.incrementTime()

    if (isIntervalBased.value) {
      handleIntervalTimer()
    } else {
      checkAudioCues()
      checkCompletion()
    }
  }

  const handleIntervalTimer = () => {
    timerStore.incrementIntervalTime()

    const interval = currentInterval.value
    if (!interval) return

    const remaining = interval.duration - intervalTime.value

    // Voice countdown: "ten seconds", 3, 2, 1
    if (remaining === 10 || remaining === 3 || remaining === 2 || remaining === 1) {
      if (lastIntervalCue.value !== remaining) {
        speak(remaining === 10 ? 'ten seconds' : remaining.toString())
        playCountdown()
        lastIntervalCue.value = remaining
      }
    }

    // Interval complete
    if (intervalTime.value >= interval.duration) {
      timerStore.resetIntervalTime()
      lastIntervalCue.value = -1

      // Check if this was the last interval
      if (currentIntervalIndex.value >= totalIntervals.value - 1) {
        // Workout complete
        speak('Great work!')
        playBeep()
        timerStore.complete()
        pauseTimer()
      } else {
        // Move to next interval
        timerStore.nextInterval()
        const nextInterval = currentInterval.value

        if (nextInterval) {
          if (nextInterval.type === 'rest') {
            speak('Rest')
          } else if (nextInterval.type === 'work') {
            // Extract round number from label (e.g., "Minute 3" -> "3")
            const roundMatch = nextInterval.label.match(/\d+/)
            if (roundMatch) {
              const roundNum = parseInt(roundMatch[0])
              // Check if this is the last work interval
              const isLastRound = currentIntervalIndex.value >= totalIntervals.value - 2
              if (isLastRound) {
                speak(`Final round`)
              } else {
                speak(`Round ${roundNum}`)
              }
            }
          }
        }
      }
    }
  }

  const pauseTimer = () => {
    timerStore.pause()
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }
  }

  const resetTimer = () => {
    timerStore.reset()
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }
    lastCueTime.value = -1
    lastIntervalCue.value = -1
  }

  const checkAudioCues = () => {
    if (!config.value?.total_seconds) return

    const remaining = config.value.total_seconds - currentTime.value

    // Voice countdown: "ten seconds", 3, 2, 1
    if (remaining === 10 || remaining === 3 || remaining === 2 || remaining === 1) {
      if (lastCueTime.value !== remaining) {
        speak(remaining === 10 ? 'ten seconds' : remaining.toString())
        playCountdown()
        lastCueTime.value = remaining
      }
    }

    // Other audio cues
    if (config.value?.audio_cues) {
      const cues = config.value.audio_cues.filter(cue => {
        if (cue.time < 0) {
          // Negative times are from end
          const totalSeconds = config.value?.total_seconds || 0
          const triggerTime = totalSeconds + cue.time
          return currentTime.value === triggerTime && triggerTime !== lastCueTime.value
        }
        return cue.time === currentTime.value && cue.time !== lastCueTime.value
      })

      cues.forEach(cue => {
        if (cue.type !== 'countdown') {
          speak(cue.message)
          lastCueTime.value = cue.time
        }
      })
    }
  }

  const checkCompletion = () => {
    if (config.value?.total_seconds && currentTime.value >= config.value.total_seconds) {
      timerStore.complete()
      pauseTimer()
      playBeep()
    }
  }

  onUnmounted(() => {
    if (intervalId) {
      clearInterval(intervalId)
    }
  })

  return {
    startTimer,
    pauseTimer,
    resetTimer,
  }
}
