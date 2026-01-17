<script setup lang="ts">
import { computed } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { useTimer } from '@/composables/useTimer'
import Button from '@/components/ui/Button.vue'
import { Play, Pause, RotateCcw, Volume2, VolumeX } from 'lucide-vue-next'
import { useAudio } from '@/composables/useAudio'

const timerStore = useTimerStore()
const { state, isPreparing } = storeToRefs(timerStore)
const { startTimer, pauseTimer, resetTimer } = useTimer()
const { audioEnabled, toggleAudio } = useAudio()

const handleStartPause = () => {
  if (state.value === TimerState.RUNNING || state.value === TimerState.PREPARING) {
    pauseTimer()
  } else {
    startTimer()
  }
}

const isActive = computed(() =>
  state.value === TimerState.RUNNING || state.value === TimerState.PREPARING
)
</script>

<template>
  <div class="flex items-center justify-center gap-4">
    <Button
      @click="handleStartPause"
      size="lg"
      class="min-w-32"
    >
      <Play v-if="!isActive" class="mr-2 h-5 w-5" />
      <Pause v-else class="mr-2 h-5 w-5" />
      {{ isActive ? 'Pause' : 'Start' }}
    </Button>

    <Button
      @click="resetTimer"
      variant="outline"
      size="lg"
    >
      <RotateCcw class="mr-2 h-5 w-5" />
      Reset
    </Button>

    <Button
      @click="toggleAudio"
      variant="ghost"
      size="icon"
    >
      <Volume2 v-if="audioEnabled" class="h-5 w-5" />
      <VolumeX v-else class="h-5 w-5" />
    </Button>
  </div>
</template>
