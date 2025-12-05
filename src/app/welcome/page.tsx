import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export const dynamic = 'force-dynamic'

export default async function WelcomePage() {
  const supabase = createClient()
  const { data: { session } } = await supabase.auth.getSession()

  if (session) {
    redirect('/dashboard')
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full space-y-8 p-8">
        <h1 className="text-4xl font-bold text-center">Welcome to GroundUp</h1>
        <p className="text-center text-gray-600">
          The Dungeon Finder for startup co-founders
        </p>
        <div className="space-y-4">
          <Link
            href="/signin"
            className="block w-full text-center py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Sign in
          </Link>
          <Link
            href="/signup"
            className="block w-full text-center py-3 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Create account
          </Link>
        </div>
      </div>
    </div>
  )
}
