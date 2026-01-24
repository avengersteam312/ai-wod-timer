<script setup lang="ts">
import { ref } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import Button from '@/components/ui/Button.vue'
import Card from '@/components/ui/Card.vue'
import Textarea from '@/components/ui/Textarea.vue'
import { Loader2 } from 'lucide-vue-next'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()

const workoutText = ref('')

const exampleWorkouts = [
  {
    name: 'Fran',
    text: 'For Time:\n21-15-9 reps of:\nThrusters (95/65 lbs)\nPull-ups'
  },
  {
    name: 'AMRAP',
    text: 'AMRAP 20min:\n10 Wall Balls (20/14 lbs)\n10 Box Jumps (24/20 in)\n10 Burpees'
  },
  {
    name: 'EMOM',
    text: 'EMOM 12min:\n5 Power Cleans (135/95 lbs)\n10 Push-ups'
  },
  {
    name: 'Tabata',
    text: 'Tabata:\nAir Squats\n(20 seconds work / 10 seconds rest for 8 rounds)'
  }
]

const loadExample = (example: typeof exampleWorkouts[0]) => {
  workoutText.value = example.text
}

const handleParse = async () => {
  if (!workoutText.value.trim()) return

  try {
    const parsed = await workoutStore.parseWorkout(workoutText.value)
    timerStore.setConfig(parsed.timer_config)
  } catch (error) {
    console.error('Failed to parse workout:', error)
  }
}

const emit = defineEmits<{
  workoutParsed: []
  switchToManual: []
}>()

const parseAndNavigate = async () => {
  await handleParse()
  if (workoutStore.currentWorkout) {
    emit('workoutParsed')
  }
}
</script>

<template>
  <div class="space-y-6">
    <div class="text-center">
      <h1 class="text-4xl font-bold tracking-tight mb-2">AI Workout Timer</h1>
      <p class="text-muted-foreground">Paste your workout and let AI generate a smart timer</p>
    </div>

    <Card class="p-6">
      <div class="space-y-4">
        <div>
          <label class="text-sm font-medium mb-2 block">Your Workout</label>
          <Textarea
            v-model="workoutText"
            placeholder="Paste your workout here...

Example:
AMRAP 20min:
10 Wall Balls (20/14 lbs)
10 Box Jumps (24/20 in)
10 Burpees"
            class="min-h-[200px] font-mono"
          />
        </div>

        <div class="flex gap-2">
          <Button
            @click="parseAndNavigate"
            :disabled="!workoutText.trim() || workoutStore.isLoading"
            class="flex-1"
          >
            <Loader2 v-if="workoutStore.isLoading" class="mr-2 h-4 w-4 animate-spin" />
            Start Timer
          </Button>
        </div>

        <div v-if="workoutStore.error" class="text-sm text-destructive">
          {{ workoutStore.error }}
        </div>
      </div>
    </Card>

    <div>
      <h3 class="text-sm font-medium mb-3">Example Workouts</h3>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-2">
        <Button
          v-for="example in exampleWorkouts"
          :key="example.name"
          @click="loadExample(example)"
          variant="outline"
          size="sm"
        >
          {{ example.name }}
        </Button>
      </div>
    </div>

    <!-- Switch to Manual mode link -->
    <div class="text-center pt-2">
      <button
        @click="$emit('switchToManual')"
        class="text-muted-foreground hover:text-foreground text-sm transition-colors"
      >
        Or create manual timer →
      </button>
    </div>
  </div>
</template>
