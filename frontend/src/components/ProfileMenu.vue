<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useSupabaseAuthStore } from '@/stores/supabaseAuthStore'
import { User, LogOut, ChevronDown } from 'lucide-vue-next'
import { onClickOutside } from '@vueuse/core'

const router = useRouter()
const authStore = useSupabaseAuthStore()
const isOpen = ref(false)
const menuRef = ref<HTMLElement | null>(null)

// Reference icons for TypeScript 

// Close menu when clicking outside
onClickOutside(menuRef, () => {
  isOpen.value = false
})

const userEmail = computed(() => authStore.userEmail || 'User')

const handleLogout = async () => {
  const result = await authStore.signOut()
  isOpen.value = false
  if (result.success) {
    router.push('/login')
  } else {
    console.error('Logout failed:', result.error)
  }
}

const toggleMenu = () => {
  isOpen.value = !isOpen.value
}
</script>

<template>
  <div ref="menuRef" class="relative">
    <!-- Profile Button -->
    <button
      @click="toggleMenu"
      class="flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-surface transition-colors focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
      aria-label="Profile menu"
      :aria-expanded="isOpen"
      aria-haspopup="true"
    >
      <div class="h-8 w-8 rounded-full bg-primary flex items-center justify-center text-primary-foreground">
        <User class="h-4 w-4" />
      </div>
      <span class="hidden sm:block text-sm font-medium text-foreground max-w-[120px] truncate">
        {{ userEmail }}
      </span>
      <ChevronDown 
        class="h-4 w-4 text-muted-foreground transition-transform"
        :class="{ 'rotate-180': isOpen }"
      />
    </button>

    <!-- Dropdown Menu -->
    <transition
      enter-active-class="transition ease-out duration-100"
      enter-from-class="opacity-0 scale-95"
      enter-to-class="opacity-100 scale-100"
      leave-active-class="transition ease-in duration-75"
      leave-from-class="opacity-100 scale-100"
      leave-to-class="opacity-0 scale-95"
    >
      <div
        v-if="isOpen"
        class="absolute right-0 mt-2 w-56 rounded-lg border bg-card shadow-lg z-50"
      >
        <div class="p-2">
          <!-- User Info -->
          <div class="px-3 py-2 border-b border-border">
            <p class="text-xs font-medium text-muted-foreground mb-1">Signed in as</p>
            <p class="text-sm font-semibold text-foreground truncate">{{ userEmail }}</p>
          </div>

          <!-- Logout Button -->
          <button
            @click="handleLogout"
            class="w-full flex items-center gap-2 px-3 py-2 text-sm text-foreground hover:bg-destructive/10 hover:text-destructive rounded-md transition-colors"
          >
            <LogOut class="h-4 w-4" />
            <span>Sign out</span>
          </button>
        </div>
      </div>
    </transition>
  </div>
</template>
