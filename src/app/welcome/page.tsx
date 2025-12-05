// src/app/welcome/page.tsx
import Link from 'next/link'
import { createServerSupabaseClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function Welcome() {
  const supabase = createServerSupabaseClient()
  const { data