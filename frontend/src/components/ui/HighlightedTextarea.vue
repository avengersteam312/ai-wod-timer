<script setup lang="ts">
import { computed, ref, watch, nextTick, onMounted } from 'vue'
import { useWorkoutHighlighting } from '@/composables/useWorkoutHighlighting'
import { cn } from '@/lib/utils'

interface Props {
  modelValue?: string
  placeholder?: string
  class?: string
}

const props = defineProps<Props>()
const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const textareaRef = ref<HTMLTextAreaElement>()
const overlayRef = ref<HTMLDivElement>()
const text = computed({
  get: () => props.modelValue || '',
  set: (value) => emit('update:modelValue', value),
})

const { highlights } = useWorkoutHighlighting(text)

// Sync scroll between textarea and overlay
const handleScroll = () => {
  if (overlayRef.value && textareaRef.value) {
    overlayRef.value.scrollTop = textareaRef.value.scrollTop
    overlayRef.value.scrollLeft = textareaRef.value.scrollLeft
  }
}

const handleInput = (e: Event) => {
  const target = e.target as HTMLTextAreaElement
  text.value = target.value
  handleScroll()
}

// Sync textarea dimensions with overlay
const syncDimensions = () => {
  if (textareaRef.value && overlayRef.value) {
    const textarea = textareaRef.value
    const styles = window.getComputedStyle(textarea)
    
    // Copy all relevant styles to ensure perfect alignment
    overlayRef.value.style.width = `${textarea.offsetWidth}px`
    overlayRef.value.style.height = `${textarea.offsetHeight}px`
    overlayRef.value.style.padding = styles.padding
    overlayRef.value.style.paddingTop = styles.paddingTop
    overlayRef.value.style.paddingRight = styles.paddingRight
    overlayRef.value.style.paddingBottom = styles.paddingBottom
    overlayRef.value.style.paddingLeft = styles.paddingLeft
    overlayRef.value.style.border = styles.border
    overlayRef.value.style.borderRadius = styles.borderRadius
    overlayRef.value.style.fontSize = styles.fontSize
    overlayRef.value.style.fontFamily = styles.fontFamily
    overlayRef.value.style.fontWeight = styles.fontWeight
    overlayRef.value.style.fontStyle = styles.fontStyle
    overlayRef.value.style.lineHeight = styles.lineHeight
    overlayRef.value.style.letterSpacing = styles.letterSpacing
    overlayRef.value.style.textIndent = styles.textIndent
    overlayRef.value.style.wordSpacing = styles.wordSpacing
    overlayRef.value.style.boxSizing = styles.boxSizing
    overlayRef.value.style.margin = styles.margin
  }
}

watch(() => text.value, () => {
  nextTick(() => {
    syncDimensions()
    handleScroll()
  })
})

onMounted(() => {
  nextTick(() => {
    syncDimensions()
    handleScroll()
  })
  window.addEventListener('resize', syncDimensions)
})

// Escape HTML while preserving whitespace
const escapeHtml = (str: string) => {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
}

// Render highlighted text - preserve exact text structure
const renderHighlightedText = () => {
  if (!text.value) return ''
  
  // Build the highlighted HTML by reconstructing the exact text with highlights
  let result = ''
  let currentIndex = 0
  
  highlights.value.forEach((segment) => {
    // Ensure we're at the right position (add any missing text)
    if (segment.start > currentIndex) {
      const missingText = text.value.substring(currentIndex, segment.start)
      result += escapeHtml(missingText)
    }
    
    const escaped = escapeHtml(segment.text)
    
    if (segment.type === 'normal') {
      result += escaped
    } else if (segment.type === 'keyword') {
      // Minimal styling - no padding to avoid character misalignment
      result += `<mark class="bg-yellow-500/30 text-yellow-300" style="padding: 0; margin: 0; display: inline; border-radius: 2px; line-height: inherit;">${escaped}</mark>`
    } else if (segment.type === 'time') {
      result += `<mark class="bg-blue-500/30 text-blue-300" style="padding: 0; margin: 0; display: inline; border-radius: 2px; line-height: inherit;">${escaped}</mark>`
    }
    
    currentIndex = segment.end
  })
  
  // Add any remaining text
  if (currentIndex < text.value.length) {
    result += escapeHtml(text.value.substring(currentIndex))
  }
  
  return result
}

const highlightedHtml = computed(() => renderHighlightedText())
</script>

<template>
  <div class="relative w-full">
    <!-- Overlay for highlighting -->
    <div
      ref="overlayRef"
      class="absolute inset-0 pointer-events-none overflow-hidden whitespace-pre-wrap break-words text-sm font-mono"
      :class="cn('ring-offset-background', props.class)"
      v-html="highlightedHtml"
      style="color: transparent; overflow-wrap: break-word; word-wrap: break-word; white-space: pre-wrap; z-index: 1; user-select: none;"
    />
    
    <!-- Actual textarea -->
    <textarea
      ref="textareaRef"
      :value="text"
      @input="handleInput"
      @scroll="handleScroll"
      @focus="syncDimensions"
      :placeholder="placeholder"
      :class="cn(
        'relative w-full bg-transparent text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 resize-none',
        'flex min-h-[80px] rounded-md border border-input px-3 py-2 text-sm ring-offset-background',
        props.class
      )"
      style="caret-color: hsl(var(--foreground)); position: relative; z-index: 2;"
    />
  </div>
</template>
