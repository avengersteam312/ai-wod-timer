/**
 * Supabase Database Types
 *
 * This file contains TypeScript types for the Supabase database schema.
 *
 * To regenerate these types from your Supabase project, run:
 * npx supabase gen types typescript --project-id <project-id> > src/types/supabase.ts
 *
 * Or with a local Supabase instance:
 * npx supabase gen types typescript --local > src/types/supabase.ts
 */

import type { ParsedWorkout } from './workout'

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          display_name: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          display_name?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          display_name?: string | null
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'profiles_id_fkey'
            columns: ['id']
            isOneToOne: true
            referencedRelation: 'users'
            referencedColumns: ['id']
          }
        ]
      }
      workouts: {
        Row: {
          id: string
          user_id: string
          name: string
          raw_input: string | null
          parsed_config: ParsedWorkout
          is_favorite: boolean
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          name: string
          raw_input?: string | null
          parsed_config: ParsedWorkout
          is_favorite?: boolean
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          name?: string
          raw_input?: string | null
          parsed_config?: ParsedWorkout
          is_favorite?: boolean
          created_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'workouts_user_id_fkey'
            columns: ['user_id']
            isOneToOne: false
            referencedRelation: 'users'
            referencedColumns: ['id']
          }
        ]
      }
      workout_sessions: {
        Row: {
          id: string
          user_id: string
          workout_id: string | null
          workout_snapshot: ParsedWorkout
          started_at: string
          completed_at: string | null
          duration_seconds: number | null
          status: Database['public']['Enums']['session_status']
        }
        Insert: {
          id?: string
          user_id: string
          workout_id?: string | null
          workout_snapshot: ParsedWorkout
          started_at?: string
          completed_at?: string | null
          duration_seconds?: number | null
          status?: Database['public']['Enums']['session_status']
        }
        Update: {
          id?: string
          user_id?: string
          workout_id?: string | null
          workout_snapshot?: ParsedWorkout
          started_at?: string
          completed_at?: string | null
          duration_seconds?: number | null
          status?: Database['public']['Enums']['session_status']
        }
        Relationships: [
          {
            foreignKeyName: 'workout_sessions_user_id_fkey'
            columns: ['user_id']
            isOneToOne: false
            referencedRelation: 'users'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'workout_sessions_workout_id_fkey'
            columns: ['workout_id']
            isOneToOne: false
            referencedRelation: 'workouts'
            referencedColumns: ['id']
          }
        ]
      }
      user_preferences: {
        Row: {
          user_id: string
          audio_enabled: boolean
          voice_type: string
          theme: string
          default_rest_seconds: number
          countdown_seconds: number
          updated_at: string | null
        }
        Insert: {
          user_id: string
          audio_enabled?: boolean
          voice_type?: string
          theme?: string
          default_rest_seconds?: number
          countdown_seconds?: number
          updated_at?: string | null
        }
        Update: {
          user_id?: string
          audio_enabled?: boolean
          voice_type?: string
          theme?: string
          default_rest_seconds?: number
          countdown_seconds?: number
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: 'user_preferences_user_id_fkey'
            columns: ['user_id']
            isOneToOne: true
            referencedRelation: 'users'
            referencedColumns: ['id']
          }
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      session_status: 'in_progress' | 'completed' | 'abandoned'
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

/**
 * Helper types for easier access to table types
 */

// Profile types
export type Profile = Database['public']['Tables']['profiles']['Row']
export type ProfileInsert = Database['public']['Tables']['profiles']['Insert']
export type ProfileUpdate = Database['public']['Tables']['profiles']['Update']

// Workout types
export type Workout = Database['public']['Tables']['workouts']['Row']
export type WorkoutInsert = Database['public']['Tables']['workouts']['Insert']
export type WorkoutUpdate = Database['public']['Tables']['workouts']['Update']

// Session types
export type WorkoutSession = Database['public']['Tables']['workout_sessions']['Row']
export type WorkoutSessionInsert = Database['public']['Tables']['workout_sessions']['Insert']
export type WorkoutSessionUpdate = Database['public']['Tables']['workout_sessions']['Update']
export type SessionStatus = Database['public']['Enums']['session_status']

// Preferences types
export type UserPreferences = Database['public']['Tables']['user_preferences']['Row']
export type UserPreferencesInsert = Database['public']['Tables']['user_preferences']['Insert']
export type UserPreferencesUpdate = Database['public']['Tables']['user_preferences']['Update']

/**
 * Type helper for Supabase client with database types
 */
export type Tables<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Row']
export type TablesInsert<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Insert']
export type TablesUpdate<T extends keyof Database['public']['Tables']> =
  Database['public']['Tables'][T]['Update']
export type Enums<T extends keyof Database['public']['Enums']> =
  Database['public']['Enums'][T]
