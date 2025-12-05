// src/lib/supabase/server.ts
import { createServerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export const createServerSupabaseClient = () =>
  createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
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
    }
  )