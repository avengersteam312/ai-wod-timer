import { ref, onUnmounted } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { useAudio } from './useAudio'
import { useHaptics } from './useHaptics'
import { useKeepAwake } from './useKeepAwake'

export function useTimer() {
  const timerStore = useTimerStore()
  const { state, currentTime, config, prepTime, prepDuration, intervalTime, currentInterval, currentIntervalIndex, totalIntervals, isIntervalBased, isWorkRestTimer, workRestPhase, workRestRestTime, currentRound, repeatRound, isOpenEndedInterval } = storeToRefs(timerStore)
  const { playBeep, playCountdown, playGo, playDone, playHalfway, playTenSeconds, playLastRound, playRest, playRoundOne, playNextRound, playNumber, speak } = useAudio()
  const { vibrateWarning, vibrateSuccess } = useHaptics()
  const { keepAwake, allowSleep } = useKeepAwake()

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
    keepAwake()
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

    // Announce countdown: "ten seconds" (voice only), 3, 2, 1 (voice + beep + haptic)
    if (remaining === 10) {
      playTenSeconds()
      vibrateWarning()
    } else if (remaining === 5) {
      // Announce first round at 5 seconds
      playRoundOne()
      vibrateWarning()
    } else if (remaining > 0 && remaining <= 3) {
      playNumber(remaining)
      playCountdown()
      vibrateWarning()
    }

    // Preparation complete, start workout
    if (prepTime.value >= prepDuration.value) {
      playGo()
      vibrateSuccess()
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

      // Voice countdown: "ten seconds" (voice only), 3, 2, 1 (voice + beep + haptic)
      if (remaining === 10) {
        playTenSeconds()
        vibrateWarning()
      } else if (remaining === 5) {
        // Announce upcoming round at 5 seconds
        const totalRounds = config.value?.rounds || 1
        const nextRound = currentRound.value + 1
        if (nextRound >= totalRounds) {
          playLastRound()
        } else {
          playNextRound()
        }
        vibrateWarning()
      } else if (remaining === 3 || remaining === 2 || remaining === 1) {
        playNumber(remaining)
        playCountdown()
        vibrateWarning()
      }

      // Rest complete
      if (remaining <= 0) {
        const totalRounds = config.value?.rounds || 1
        if (currentRound.value >= totalRounds) {
          // Workout complete
          playDone()
          vibrateSuccess()
          timerStore.complete()
          pauseTimer()
        } else {
          // Start next work round
          timerStore.startNextWorkRestRound()
          playGo()
          vibrateSuccess()
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
      playDone()
      vibrateSuccess()
      timerStore.complete()
      pauseTimer()
    } else {
      timerStore.startWorkRestRest()
      playRest()
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
      playDone()
      vibrateSuccess()
      timerStore.complete()
      pauseTimer()
    } else {
      // Move to next interval
      timerStore.nextInterval()
      const nextInterval = currentInterval.value

      if (nextInterval) {
        if (nextInterval.type === 'rest') {
          playRest()
        } else if (nextInterval.type === 'work') {
          const workRoundNum = countWorkRounds(currentIntervalIndex.value)
          const intervals = config.value?.intervals || []
          const remainingWorkIntervals = intervals.slice(currentIntervalIndex.value + 1).filter(i => i.type === 'work').length
          if (remainingWorkIntervals === 0) {
            playLastRound()
          } else if (workRoundNum === 1) {
            playRoundOne()
          } else {
            playNextRound()
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
      playDone()
      vibrateSuccess()
      timerStore.complete()
      pauseTimer()
    } else {
      // Move to next interval
      timerStore.nextInterval()
      const nextInterval = currentInterval.value

      if (nextInterval) {
        if (nextInterval.type === 'rest') {
          playRest()
        } else if (nextInterval.type === 'work') {
          const workRoundNum = countWorkRounds(currentIntervalIndex.value)
          const intervals = config.value?.intervals || []
          const remainingWorkIntervals = intervals.slice(currentIntervalIndex.value + 1).filter(i => i.type === 'work').length
          if (remainingWorkIntervals === 0) {
            playLastRound()
          } else if (workRoundNum === 1) {
            playRoundOne()
          } else {
            playNextRound()
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

    // Announce "halfway" for work intervals (skip if coincides with 10 seconds)
    if (isHalfway && !announcedIntervalHalfway.value && remaining !== 10) {
      playHalfway()
      announcedIntervalHalfway.value = true
    }

    // Voice countdown: "ten seconds" (voice only), 5 (haptic only), 3, 2, 1 (voice + beep + haptic)
    if (remaining === 10) {
      if (lastIntervalCue.value !== remaining) {
        playTenSeconds()
        vibrateWarning()
        lastIntervalCue.value = remaining
      }
    } else if (remaining === 5) {
      if (lastIntervalCue.value !== remaining) {
        // Announce upcoming round at 5 seconds (only for work intervals, not rest)
        const nextIntervalIndex = currentIntervalIndex.value + 1
        if (nextIntervalIndex < totalIntervals.value) {
          const intervals = config.value?.intervals || []
          const nextInterval = intervals[nextIntervalIndex]
          if (nextInterval?.type === 'work') {
            const workRoundNum = countWorkRounds(nextIntervalIndex)
            const remainingWorkIntervals = intervals.slice(nextIntervalIndex + 1).filter((i: { type: string }) => i.type === 'work').length
            if (remainingWorkIntervals === 0) {
              playLastRound()
            } else if (workRoundNum === 1) {
              playRoundOne()
            } else {
              playNextRound()
            }
          }
        }
        vibrateWarning()
        lastIntervalCue.value = remaining
      }
    } else if (remaining === 3 || remaining === 2 || remaining === 1) {
      if (lastIntervalCue.value !== remaining) {
        playNumber(remaining)
        playCountdown()
        vibrateWarning()
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
        playBeep()
        return
      }

      // Check if this was the last interval
      if (currentIntervalIndex.value >= totalIntervals.value - 1) {
        // Workout complete
        playDone()
        vibrateSuccess()
        timerStore.complete()
        pauseTimer()
      } else {
        // Move to next interval
        timerStore.nextInterval()
        const nextInterval = currentInterval.value
        if (nextInterval?.type === 'rest') {
          playRest()
          playBeep()
        } else if (nextInterval?.type === 'work') {
          playGo()
          vibrateSuccess()
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
    allowSleep()
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
    allowSleep()
  }

  const checkAudioCues = () => {
    if (!config.value?.total_seconds) return

    const remaining = config.value.total_seconds - currentTime.value
    const halfwayPoint = Math.floor(config.value.total_seconds / 2)

    // Announce "halfway" for AMRAP and for_time timers
    const timerType = config.value.type
    if ((timerType === 'amrap' || timerType === 'for_time') && currentTime.value === halfwayPoint && halfwayPoint > 0 && !announcedHalfway.value) {
      playHalfway()
      announcedHalfway.value = true
    }

    // Voice countdown: "ten seconds" (voice only + haptic), 5 (haptic only), 3, 2, 1 (voice + beep + haptic)
    if (remaining === 10) {
      if (lastCueTime.value !== remaining) {
        playTenSeconds()
        vibrateWarning()
        lastCueTime.value = remaining
      }
    } else if (remaining === 5) {
      if (lastCueTime.value !== remaining) {
        vibrateWarning()
        lastCueTime.value = remaining
      }
    } else if (remaining === 3 || remaining === 2 || remaining === 1) {
      if (lastCueTime.value !== remaining) {
        playNumber(remaining)
        playCountdown()
        vibrateWarning()
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
      playDone()
      vibrateSuccess()
    }
  }

  onUnmounted(() => {
    if (intervalId) {
      clearInterval(intervalId)
    }
    allowSleep()
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
