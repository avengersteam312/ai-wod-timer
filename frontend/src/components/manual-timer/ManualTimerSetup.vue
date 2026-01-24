<script setup lang="ts">
import { ref, computed } from 'vue'
import { useTimerStore } from '@/stores/timerStore'
import { useWorkoutStore } from '@/stores/workoutStore'
import Button from '@/components/ui/Button.vue'

// Sub-components
import TimerTypeSelector from './TimerTypeSelector.vue'
import TimerConfigHeader from './TimerConfigHeader.vue'
import RestTimerConfig from './configs/RestTimerConfig.vue'
import StopwatchConfig from './configs/StopwatchConfig.vue'
import AmrapForTimeConfig from './configs/AmrapForTimeConfig.vue'
import TabataConfig from './configs/TabataConfig.vue'
import CustomIntervalConfig from './configs/CustomIntervalConfig.vue'
import EmomConfig from './configs/EmomConfig.vue'
import WorkRestConfig from './configs/WorkRestConfig.vue'

// Composables
import {
  type TimerType,
  buildTimerConfig,
  buildManualWorkout
} from './composables/useTimerConfigBuilder'

const timerStore = useTimerStore()
const workoutStore = useWorkoutStore()

defineEmits<{
  switchToAI: []
}>()

// Navigation state
const step = ref<'select' | 'customize'>('select')
const selectedType = ref<TimerType | null>(null)

// Countdown (preparation time)
const countdownSeconds = ref(5)

// Rest Timer state
const restMinutes = ref(1)
const restSeconds = ref(0)

// AMRAP / For Time state
const durationMinutes = ref(10)
const durationSeconds = ref(0)

// Tabata state
const tabataWorkSeconds = ref(20)
const tabataRestSeconds = ref(10)
const tabataRounds = ref(8)

// Custom Interval state
const workMinutes = ref(0)
const workSeconds = ref(30)
const intervalRestMinutes = ref(0)
const intervalRestSeconds = ref(10)
const intervalRounds = ref(8)

// EMOM state
const emomRounds = ref(10)
const emomIntervalMinutes = ref(1)

// Work & Rest state
const workRestRounds = ref(5)

// Computed
const totalRestSeconds = computed(() => restMinutes.value * 60 + restSeconds.value)
const totalDurationSeconds = computed(() => durationMinutes.value * 60 + durationSeconds.value)
const totalWorkSeconds = computed(() => workMinutes.value * 60 + workSeconds.value)

const isValidConfig = computed(() => {
  if (!selectedType.value) return false
  switch (selectedType.value) {
    case 'rest':
      return totalRestSeconds.value > 0
    case 'stopwatch':
      return true
    case 'amrap':
      return totalDurationSeconds.value > 0
    case 'for_time':
      return true
    case 'tabata':
      return tabataWorkSeconds.value > 0 && tabataRounds.value > 0
    case 'custom_interval':
      return totalWorkSeconds.value > 0 && intervalRounds.value > 0
    case 'emom':
      return emomRounds.value > 0 && emomIntervalMinutes.value > 0
    case 'work_rest':
      return workRestRounds.value > 0
    default:
      return false
  }
})

// Actions
const selectType = (type: TimerType) => {
  selectedType.value = type

  // Set appropriate defaults
  if (type === 'for_time') {
    durationMinutes.value = 0
    durationSeconds.value = 0
  } else if (type === 'amrap') {
    durationMinutes.value = 10
    durationSeconds.value = 0
  }

  step.value = 'customize'
}

const goBack = () => {
  step.value = 'select'
}

const handleQuickStart = (seconds: number) => {
  restMinutes.value = Math.floor(seconds / 60)
  restSeconds.value = seconds % 60
  selectedType.value = 'rest'

  const timerConfig = buildTimerConfig('rest', {
    rest: { minutes: restMinutes.value, seconds: restSeconds.value }
  })
  const workout = buildManualWorkout('rest', timerConfig)

  workoutStore.setManualWorkout(workout)
  timerStore.setConfig(workout.timer_config, { autoStart: true, skipPreparation: true })
}

const handleStart = () => {
  if (!isValidConfig.value || !selectedType.value) return

  const timerConfig = buildTimerConfig(selectedType.value, {
    rest: { minutes: restMinutes.value, seconds: restSeconds.value },
    duration: { minutes: durationMinutes.value, seconds: durationSeconds.value },
    tabata: {
      workSeconds: tabataWorkSeconds.value,
      restSeconds: tabataRestSeconds.value,
      rounds: tabataRounds.value
    },
    customInterval: {
      workMinutes: workMinutes.value,
      workSeconds: workSeconds.value,
      restMinutes: intervalRestMinutes.value,
      restSeconds: intervalRestSeconds.value,
      rounds: intervalRounds.value
    },
    emom: { rounds: emomRounds.value, intervalMinutes: emomIntervalMinutes.value },
    workRest: { rounds: workRestRounds.value }
  })

  const workout = buildManualWorkout(selectedType.value, timerConfig)
  workoutStore.setManualWorkout(workout)

  const isRestTimer = selectedType.value === 'rest'
  const skipCountdown = isRestTimer || countdownSeconds.value === 0

  timerStore.setConfig(workout.timer_config, {
    autoStart: isRestTimer,
    skipPreparation: skipCountdown,
    prepDuration: countdownSeconds.value
  })
}
</script>

<template>
  <div class="space-y-6">
    <!-- Step 1: Select Timer Type -->
    <TimerTypeSelector
      v-if="step === 'select'"
      @select="selectType"
      @switch-to-a-i="$emit('switchToAI')"
    />

    <!-- Step 2: Configure Timer -->
    <template v-else-if="step === 'customize' && selectedType">
      <TimerConfigHeader
        :type="selectedType"
        v-model:countdown="countdownSeconds"
        @back="goBack"
      />

      <!-- Timer-specific configs -->
      <RestTimerConfig
        v-if="selectedType === 'rest'"
        v-model:minutes="restMinutes"
        v-model:seconds="restSeconds"
        @quick-start="handleQuickStart"
      />

      <StopwatchConfig v-else-if="selectedType === 'stopwatch'" />

      <AmrapForTimeConfig
        v-else-if="selectedType === 'amrap' || selectedType === 'for_time'"
        :type="selectedType"
        v-model:minutes="durationMinutes"
        v-model:seconds="durationSeconds"
      />

      <TabataConfig
        v-else-if="selectedType === 'tabata'"
        v-model:workSeconds="tabataWorkSeconds"
        v-model:restSeconds="tabataRestSeconds"
        v-model:rounds="tabataRounds"
      />

      <CustomIntervalConfig
        v-else-if="selectedType === 'custom_interval'"
        v-model:workMinutes="workMinutes"
        v-model:workSeconds="workSeconds"
        v-model:restMinutes="intervalRestMinutes"
        v-model:restSeconds="intervalRestSeconds"
        v-model:rounds="intervalRounds"
      />

      <EmomConfig
        v-else-if="selectedType === 'emom'"
        v-model:rounds="emomRounds"
        v-model:intervalMinutes="emomIntervalMinutes"
      />

      <WorkRestConfig
        v-else-if="selectedType === 'work_rest'"
        v-model:rounds="workRestRounds"
      />

      <!-- Start Button -->
      <Button
        @click="handleStart"
        :disabled="!isValidConfig"
        class="w-full py-6 text-lg rounded-full"
      >
        Start Timer
      </Button>
    </template>
  </div>
</template>
