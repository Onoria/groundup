// src/lib/supabase/server.ts
import { createServerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export const createServerSupabaseClient = () =>
  createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        async get(name: string) {
          const cookieStore = await cookies()
          return cookieStore.get(name)?.value
        },
        async set(name: string, value: string, options: any) {
          const cookieStore = await cookies()
          try {
            cookieStore.set(name, value, options)
          } catch {
            // Ignored in server components
          }
        },
        async remove(name: string, options: any) {
          const cookieStore = await cookies()
          try {
            cookieStore.delete(name)
          } catch {
            // Ignored in server components
          }
        },
      },
    }
  )