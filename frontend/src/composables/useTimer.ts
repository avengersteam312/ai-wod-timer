import { ref, onUnmounted } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { useAudio } from './useAudio'

export function useTimer() {
  const timerStore = useTimerStore()
  const { state, currentTime, config, prepTime, prepDuration, intervalTime, currentInterval, currentIntervalIndex, totalIntervals, isIntervalBased, isWorkRestTimer, workRestPhase, workRestRestTime, currentRound, repeatRound, isOpenEndedInterval } = storeToRefs(timerStore)
  const { playBeep, playCountdown, speak } = useAudio()

  let intervalId: number | null = null
  const lastCueTime = ref(-1)
  const lastIntervalCue = ref(-1)

  // Helper: Count work rounds up to and including given index
  const countWorkRounds = (upToIndex: number): number => {
    const intervals = config.value?.intervals || []
    let count = 0
    for (let i = 0; i <= upToIndex; i++) {
      if (intervals[i]?.type === 'work') {
        count++
      }
    }
    return count
  }

  const startTimer = (skipPreparation: boolean = false) => {
    if (intervalId) return

    timerStore.start(skipPreparation)
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

    if (isWorkRestTimer.value) {
      handleWorkRestTimer()
    } else if (isIntervalBased.value) {
      handleIntervalTimer()
    } else {
      checkAudioCues()
      checkCompletion()
    }
  }

  const handleWorkRestTimer = () => {
    if (workRestPhase.value === 'work') {
      // Work phase - just increment interval time (counting up)
      timerStore.incrementIntervalTime()
    } else {
      // Rest phase - countdown
      timerStore.decrementWorkRestRestTime()

      const remaining = workRestRestTime.value

      // Voice countdown: "ten seconds", 3, 2, 1
      if (remaining === 10 || remaining === 3 || remaining === 2 || remaining === 1) {
        speak(remaining === 10 ? 'ten seconds' : remaining.toString())
        playCountdown()
      }

      // Rest complete
      if (remaining <= 0) {
        const totalRounds = config.value?.rounds || 1
        if (currentRound.value >= totalRounds) {
          // Workout complete
          speak('Great work!')
          playBeep()
          timerStore.complete()
          pauseTimer()
        } else {
          // Start next round
          timerStore.startNextWorkRestRound()
          speak(`Round ${currentRound.value}`)
          playBeep()
        }
      }
    }
  }

  // Trigger work->rest transition (called from UI when user clicks Done)
  const triggerWorkRestRest = () => {
    if (!isWorkRestTimer.value || workRestPhase.value !== 'work') return

    const totalRounds = config.value?.rounds || 1
    // If last round, complete immediately without rest
    if (currentRound.value >= totalRounds) {
      speak('Great work!')
      playBeep()
      timerStore.complete()
      pauseTimer()
    } else {
      timerStore.startWorkRestRest()
      speak('Rest')
      playBeep()
    }
  }

  // Trigger next interval for open-ended intervals (duration: 0)
  const triggerNextInterval = () => {
    if (!isOpenEndedInterval.value) return
    if (state.value !== TimerState.RUNNING && state.value !== TimerState.PAUSED) return

    const interval = currentInterval.value
    if (!interval) return

    timerStore.resetIntervalTime()
    lastIntervalCue.value = -1

    // Check if this was the last interval
    if (currentIntervalIndex.value >= totalIntervals.value - 1) {
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
          speak(`Round ${countWorkRounds(currentIntervalIndex.value)}`)
        }
        playBeep()
      }
    }
  }

  const handleIntervalTimer = () => {
    timerStore.incrementIntervalTime()

    const interval = currentInterval.value
    if (!interval) return

    // Open-ended interval (duration: 0) - just count up, don't auto-complete
    if (interval.duration === 0) {
      return
    }

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

      // Check if this is a repeating interval (until failure)
      if (interval.repeat) {
        // Increment repeat round and continue
        timerStore.incrementRepeatRound()
        speak(`Round ${repeatRound.value}`)
        playBeep()
        return
      }

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
            const workRoundNum = countWorkRounds(currentIntervalIndex.value)

            // Check if this is the last work interval
            const intervals = config.value?.intervals || []
            const remainingWorkIntervals = intervals.slice(currentIntervalIndex.value + 1).filter(i => i.type === 'work').length
            if (remainingWorkIntervals === 0) {
              speak('Final round')
            } else {
              speak(`Round ${workRoundNum}`)
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
    triggerWorkRestRest,
    triggerNextInterval,
  }
}
