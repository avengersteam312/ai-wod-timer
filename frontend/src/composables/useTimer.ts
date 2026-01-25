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
  const announcedHalfway = ref(false)
  const announcedIntervalHalfway = ref(false)

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

    // Announce countdown: "ten seconds" (voice only), 3, 2, 1 (voice + beep)
    if (remaining === 10) {
      speak('ten seconds')
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

      // Voice countdown: "ten seconds" (voice only), 3, 2, 1 (voice + beep)
      if (remaining === 10) {
        speak('ten seconds')
      } else if (remaining === 3 || remaining === 2 || remaining === 1) {
        speak(remaining.toString())
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
          const totalRounds = config.value?.rounds || 1
          if (currentRound.value >= totalRounds) {
            speak(`Round ${currentRound.value}, last round`)
          } else {
            speak(`Round ${currentRound.value}`)
          }
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
    announcedIntervalHalfway.value = false

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
          const workRoundNum = countWorkRounds(currentIntervalIndex.value)
          const intervals = config.value?.intervals || []
          const remainingWorkIntervals = intervals.slice(currentIntervalIndex.value + 1).filter(i => i.type === 'work').length
          if (remainingWorkIntervals === 0) {
            speak(`Round ${workRoundNum}, last round`)
          } else {
            speak(`Round ${workRoundNum}`)
          }
        }
        playBeep()
      }
    }
  }

  // Skip to next interval for all interval-based timers
  const skipToNextInterval = () => {
    if (!isIntervalBased.value) return
    if (state.value !== TimerState.RUNNING && state.value !== TimerState.PAUSED) return

    const interval = currentInterval.value
    if (!interval) return

    timerStore.resetIntervalTime()
    lastIntervalCue.value = -1
    announcedIntervalHalfway.value = false

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
          const workRoundNum = countWorkRounds(currentIntervalIndex.value)
          const intervals = config.value?.intervals || []
          const remainingWorkIntervals = intervals.slice(currentIntervalIndex.value + 1).filter(i => i.type === 'work').length
          if (remainingWorkIntervals === 0) {
            speak(`Round ${workRoundNum}, last round`)
          } else {
            speak(`Round ${workRoundNum}`)
          }
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
    const halfwayPoint = Math.floor(interval.duration / 2)
    const isHalfway = interval.type === 'work' && intervalTime.value === halfwayPoint && halfwayPoint > 0

    // Announce "halfway" for work intervals
    if (isHalfway && !announcedIntervalHalfway.value) {
      speak('halfway')
      announcedIntervalHalfway.value = true
    }

    // Voice countdown: "ten seconds" (voice only), 3, 2, 1 (voice + beep)
    // Skip "ten seconds" if we just announced "halfway" (they can coincide for 20-second intervals)
    if (remaining === 10 && !isHalfway) {
      if (lastIntervalCue.value !== remaining) {
        speak('ten seconds')
        lastIntervalCue.value = remaining
      }
    } else if (remaining === 3 || remaining === 2 || remaining === 1) {
      if (lastIntervalCue.value !== remaining) {
        speak(remaining.toString())
        playCountdown()
        lastIntervalCue.value = remaining
      }
    }

    // Interval complete
    if (intervalTime.value >= interval.duration) {
      timerStore.resetIntervalTime()
      lastIntervalCue.value = -1
      announcedIntervalHalfway.value = false

      // Check if this is a repeating interval (until failure)
      if (interval.repeat) {
        // Increment repeat round and type-specific round
        timerStore.incrementRepeatRound()
        if (interval.type === 'work') {
          timerStore.incrementRepeatWorkRound()
        } else if (interval.type === 'rest') {
          timerStore.incrementRepeatRestRound()
        }
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
              speak(`Round ${workRoundNum}, last round`)
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
    announcedHalfway.value = false
    announcedIntervalHalfway.value = false
  }

  const checkAudioCues = () => {
    if (!config.value?.total_seconds) return

    const remaining = config.value.total_seconds - currentTime.value
    const halfwayPoint = Math.floor(config.value.total_seconds / 2)

    // Announce "halfway" for AMRAP and for_time timers
    const timerType = config.value.type
    if ((timerType === 'amrap' || timerType === 'for_time') && currentTime.value === halfwayPoint && halfwayPoint > 0 && !announcedHalfway.value) {
      speak('halfway')
      announcedHalfway.value = true
    }

    // Voice countdown: "ten seconds" (voice only), 3, 2, 1 (voice + beep)
    if (remaining === 10) {
      if (lastCueTime.value !== remaining) {
        speak('ten seconds')
        lastCueTime.value = remaining
      }
    } else if (remaining === 3 || remaining === 2 || remaining === 1) {
      if (lastCueTime.value !== remaining) {
        speak(remaining.toString())
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
    skipToNextInterval,
  }
}
