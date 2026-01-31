/**
 * Preferences Service
 *
 * Handles CRUD operations for user preferences using Supabase.
 * Preferences store user settings like audio preferences, theme, and timer defaults.
 */
import { supabase } from '@/config/supabase'
import type {
  UserPreferences,
  UserPreferencesUpdate
} from '@/types/supabase'

// Re-export types for consumers of this service
// Use 'Preferences' as alias for backward compatibility
export type Preferences = UserPreferences
export type PreferencesUpdate = Omit<UserPreferencesUpdate, 'user_id' | 'updated_at'>

/**
 * Default preference values matching database defaults
 */
const DEFAULT_PREFERENCES: Omit<Preferences, 'user_id' | 'updated_at'> = {
  audio_enabled: true,
  voice_type: 'default',
  theme: 'dark',
  default_rest_seconds: 60,
  countdown_seconds: 10
}

/**
 * Get user preferences
 *
 * If no preferences exist for the user, creates default preferences.
 *
 * @returns The user's preferences
 * @throws Error if user is not authenticated or operation fails
 */
export async function getPreferences(): Promise<Preferences> {
  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser()

  if (userError || !user) {
    throw new Error('You must be logged in to access preferences')
  }

  // Try to fetch existing preferences
  const { data, error } = await supabase
    .from('user_preferences')
    .select('*')
    .eq('user_id', user.id)
    .single()

  if (error) {
    // If no preferences exist (PGRST116 = row not found), create default preferences
    if (error.code === 'PGRST116') {
      return createDefaultPreferences(user.id)
    }
    console.error('Error fetching preferences:', error)
    throw new Error('Failed to load preferences. Please try again.')
  }

  return data as Preferences
}

/**
 * Update user preferences
 *
 * If no preferences exist, creates default preferences with the updates applied.
 * Uses upsert to handle both create and update cases.
 *
 * @param updates - Partial preferences to update
 * @returns The updated preferences
 * @throws Error if user is not authenticated or operation fails
 */
export async function updatePreferences(updates: PreferencesUpdate): Promise<Preferences> {
  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser()

  if (userError || !user) {
    throw new Error('You must be logged in to update preferences')
  }

  // Use upsert to create if not exists, or update if exists
  const preferencesData = {
    user_id: user.id,
    ...DEFAULT_PREFERENCES,
    ...updates
  }

  const { data, error } = await supabase
    .from('user_preferences')
    .upsert(preferencesData, {
      onConflict: 'user_id'
    })
    .select()
    .single()

  if (error) {
    console.error('Error updating preferences:', error)
    throw new Error('Failed to update preferences. Please try again.')
  }

  return data as Preferences
}

/**
 * Create default preferences for a user
 *
 * @param userId - The user's UUID
 * @returns The created preferences with default values
 */
async function createDefaultPreferences(userId: string): Promise<Preferences> {
  const preferencesData = {
    user_id: userId,
    ...DEFAULT_PREFERENCES
  }

  const { data, error } = await supabase
    .from('user_preferences')
    .insert(preferencesData)
    .select()
    .single()

  if (error) {
    console.error('Error creating default preferences:', error)
    throw new Error('Failed to create preferences. Please try again.')
  }

  return data as Preferences
}
