import Link from 'next/link'
import { createServerSupabaseClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function Welcome() {
  const supabase = createServerSupabaseClient()
  const { data: { session } } = await supabase.auth.getSession()

  if (!session) redirect('/signup')

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-black flex items-center justify-center p-8">
      <div className="text-center max-w-md">
        <h1 className="text-6xl font-black text-emerald-400 mb-8">Welcome to GroundUp</h1>
        <p className="text-xl text-zinc-300 mb-12">You're in. Let's build your team.</p>
        <Link
          href="/onboarding/role"
          className="inline-block w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-4 px-10 rounded-xl text-lg transition"
        >
          Continue to Role Selection →
        </Link>
        <p className="text-sm text-zinc-500 mt-4">
          Your original tab is already logged in.<br />
          <strong>You can close this window.</strong>
        </p>
      </div>
    </div>
  )
}