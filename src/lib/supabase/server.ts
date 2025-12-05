// src/lib/supabase/server.ts
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export const createServerSupabaseClient = () =>
  createServerComponentClient({
    cookies: {
      get(name: string) {
        return cookies().get(name)?.value
      },
      set(name: string, value: string, options: any) {
        try {
          cookies().set(name, value, options)
        } catch {
          // Ignored in server components
        }
      },
      remove(name: string, options: any) {
        try {
          cookies().delete(name)
        } catch {
          // Ignored in server components
        }
      },
    },
  })