// src/lib/supabase.ts
import { createPagesBrowserClient } from '@supabase/auth-helpers-nextjs'
import { Database } from '@/types/supabase'

export const createClient = () =>
  createPagesBrowserClient<Database>()