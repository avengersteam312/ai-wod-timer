import { ref } from 'vue'

// Shared state across all instances
const voiceEnabled = ref(true)  // Only controls voice, beeps always play
const audioUnlocked = ref(false)
const synth = window.speechSynthesis

// Helper to create audio elements
const createSound = (path: string): HTMLAudioElement => {
  return new Audio(path)
}

// Preload beep sounds
const countdownSound = createSound('/sounds/beeps/countdown.mp3')
const completeSound = createSound('/sounds/beeps/complete.mp3')
const goBeepSound = createSound('/sounds/beeps/go.mp3')

// Preload voice sounds
const goSound = createSound('/sounds/voice/go.mp3')
const doneSound = createSound('/sounds/voice/done.mp3')
const halfwaySound = createSound('/sounds/voice/halfway.mp3')
const tenSecondsSound = createSound('/sounds/voice/ten-seconds.mp3')
const lastRoundSound = createSound('/sounds/voice/last-round.mp3')
const restSound = createSound('/sounds/voice/rest.mp3')
const roundOneSound = createSound('/sounds/voice/round-one.mp3')
const nextRoundSound = createSound('/sounds/voice/next-round.mp3')

// Countdown number sounds
const countdownNumbers: Record<number, HTMLAudioElement> = {
  1: createSound('/sounds/voice/1.mp3'),
  2: createSound('/sounds/voice/2.mp3'),
  3: createSound('/sounds/voice/3.mp3'),
}

// Preload to avoid delay on first play
countdownSound.load()
completeSound.load()
goSound.load()
doneSound.load()
halfwaySound.load()
tenSecondsSound.load()
lastRoundSound.load()
restSound.load()
roundOneSound.load()
nextRoundSound.load()
Object.values(countdownNumbers).forEach(sound => sound.load())

export function useAudio() {

  // Transition beep (round changes) - oscillator (always plays)
  const playBeep = () => {
    const context = new AudioContext()
    const oscillator = context.createOscillator()
    const gainNode = context.createGain()

    oscillator.connect(gainNode)
    gainNode.connect(context.destination)

    oscillator.frequency.value = 800
    gainNode.gain.value = 0.3

    oscillator.start()
    setTimeout(() => oscillator.stop(), 200)
  }

  // Countdown beep (3, 2, 1) - always plays
  const playCountdown = () => {
    countdownSound.currentTime = 0
    countdownSound.play().catch(() => {})
  }

  // Workout complete chime - always plays
  const playComplete = () => {
    completeSound.currentTime = 0
    completeSound.play().catch(() => {})
  }

  // Timer start voice (GO!) + beep
  const playGo = () => {
    if (voiceEnabled.value) {
      goSound.currentTime = 0
      goSound.play().then(() => {
        // Play go beep after voice finishes
        goBeepSound.currentTime = 0
        goBeepSound.play().catch(() => {})
      }).catch(() => {})
    } else {
      // Just play beep if voice is muted
      goBeepSound.currentTime = 0
      goBeepSound.play().catch(() => {})
    }
  }

  // Workout done voice + complete chime
  const playDone = () => {
    if (voiceEnabled.value) {
      doneSound.currentTime = 0
      doneSound.play().then(() => {
        // Play complete chime after voice finishes
        completeSound.currentTime = 0
        completeSound.play().catch(() => {})
      }).catch(() => {})
    } else {
      // Just play chime if voice is muted
      completeSound.currentTime = 0
      completeSound.play().catch(() => {})
    }
  }

  // Halfway voice
  const playHalfway = () => {
    if (!voiceEnabled.value) return

    halfwaySound.currentTime = 0
    halfwaySound.play().catch(() => {})
  }

  // Ten seconds warning voice
  const playTenSeconds = () => {
    if (!voiceEnabled.value) return

    tenSecondsSound.currentTime = 0
    tenSecondsSound.play().catch(() => {})
  }

  // Last round voice
  const playLastRound = () => {
    if (!voiceEnabled.value) return

    lastRoundSound.currentTime = 0
    lastRoundSound.play().catch(() => {})
  }

  // Rest voice
  const playRest = () => {
    if (!voiceEnabled.value) return

    restSound.currentTime = 0
    restSound.play().catch(() => {})
  }

  // Round one voice
  const playRoundOne = () => {
    if (!voiceEnabled.value) return

    roundOneSound.currentTime = 0
    roundOneSound.play().catch(() => {})
  }

  // Next round voice
  const playNextRound = () => {
    if (!voiceEnabled.value) return

    nextRoundSound.currentTime = 0
    nextRoundSound.play().catch(() => {})
  }

  // Countdown number voice (1, 2, 3)
  const playNumber = (n: number) => {
    if (!voiceEnabled.value) return

    const sound = countdownNumbers[n]
    if (sound) {
      sound.currentTime = 0
      sound.play().catch(() => {})
    }
  }

  // Fallback speech synthesis for dynamic content
  const speak = (text: string) => {
    if (!voiceEnabled.value || !synth) return

    synth.cancel()
    synth.resume()

    const utterance = new SpeechSynthesisUtterance(text)
    const voices = synth.getVoices()
    if (voices.length > 0) {
      const englishVoice = voices.find((v: SpeechSynthesisVoice) => v.lang.startsWith('en'))
      if (englishVoice) {
        utterance.voice = englishVoice
      }
    }
    utterance.rate = 1.0
    utterance.pitch = 1.0
    utterance.volume = 1.0

    synth.speak(utterance)
    synth.resume()
  }

  // Unlock audio for mobile browsers
  const unlockAudio = () => {
    if (audioUnlocked.value) return
    audioUnlocked.value = true

    // Resume AudioContext
    const context = new AudioContext()
    context.resume().catch(() => {})

    // Play one sound silently to unlock HTML5 Audio on mobile
    const unlock = countdownSound
    const originalVolume = unlock.volume
    unlock.volume = 0
    unlock.play().then(() => {
      unlock.pause()
      unlock.currentTime = 0
      unlock.volume = originalVolume
    }).catch(() => {
      unlock.volume = originalVolume
    })
  }

  const toggleVoice = () => {
    voiceEnabled.value = !voiceEnabled.value
  }

  return {
    voiceEnabled,
    unlockAudio,
    playBeep,
    playCountdown,
    playComplete,
    playGo,
    playDone,
    playHalfway,
    playTenSeconds,
    playLastRound,
    playRest,
    playRoundOne,
    playNextRound,
    playNumber,
    speak,
    toggleVoice,
  }
}
