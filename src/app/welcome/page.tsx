// src/app/welcome/page.tsx
import { createServerSupabaseClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function WelcomePage() {
  const supabase = createServerSupabaseClient()
  const { data: { session } } = await supabase.auth.getSession()

  if (!session) {
    redirect('/signup')
  }

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-semibold">Welcome to GroundUp</h1>
      <p>You are logged in as {session.user.email}</p>

      <a href="/onboarding/role" className="inline-flex border px-4 py-2 rounded">
        Continue →
      </a>

      <p className="text-sm text-gray-500">
        You may close this tab.
      </p>
    </section>
  )
}
