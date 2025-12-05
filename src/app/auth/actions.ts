'use server'

import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export async function signInAction(formData: FormData) {
  const supabase = createClient()
  const email = formData.get('email') as string
  const password = formData.get('password') as string

  const { error } = await supabase.auth.signInWithPassword({ email, password })

  if (error) redirect(`/signin?error=${encodeURIComponent(error.message)}`)
  redirect('/dashboard')
}

export async function signOutAction() {
  const supabase = createClient()
  await supabase.auth.signOut()
  redirect('/signin')
}
