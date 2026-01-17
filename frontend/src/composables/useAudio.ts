import { ref } from 'vue'

// Shared state across all instances
const audioEnabled = ref(true)
const synth = window.speechSynthesis

export function useAudio() {

  const playBeep = () => {
    if (!audioEnabled.value) return

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

  const playCountdown = () => {
    if (!audioEnabled.value) return

    const context = new AudioContext()
    const oscillator = context.createOscillator()
    const gainNode = context.createGain()

    oscillator.connect(gainNode)
    gainNode.connect(context.destination)

    oscillator.frequency.value = 600
    gainNode.gain.value = 0.2

    oscillator.start()
    setTimeout(() => oscillator.stop(), 100)
  }

  const speak = (text: string) => {
    if (!audioEnabled.value || !synth) return

    synth.cancel() // Cancel any ongoing speech

    const utterance = new SpeechSynthesisUtterance(text)
    utterance.rate = 1.0
    utterance.pitch = 1.0
    utterance.volume = 1.0

    synth.speak(utterance)
  }

  const toggleAudio = () => {
    audioEnabled.value = !audioEnabled.value
  }

  return {
    audioEnabled,
    playBeep,
    playCountdown,
    speak,
    toggleAudio,
  }
}
