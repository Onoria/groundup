// src/app/welcome/page.tsx
import Link from 'next/link'
import { redirect } from 'next/navigation'
import { createServerSupabaseClient } from '@/lib/supabase/server'

export const dynamic = 'force-dynamic'

export default async function Welcome() {
  const supabase = await createServerSupabaseClient()
  const {
    data: { session },
  } = await supabase.auth.getSession()

  if (!session) {
    redirect('/signup')
  }

  return (
    <section className="space-y-4">
      <h1 className="text-2xl font-semibold">Welcome to GroundUp</h1>
      <p>You're logged in and ready to raid.</p>

      <Link
        href="/onboarding/role"
        className="inline-flex rounded-md border px-4 py-2 text-sm"
      >
        Continue to Role Selection →
      </Link>

      <p className="text-sm text-gray-500">
        Your other tab is already logged in. You can close this window now.
      </p>
    </section>
  )
}