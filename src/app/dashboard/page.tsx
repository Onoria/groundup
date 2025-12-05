import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: { session } } = await supabase.auth.getSession()

  if (!session) {
    redirect('/signin')
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-extrabold text-gray-900">
            Welcome back, {session.user.email}!
          </h1>
          <p className="mt-4 text-xl text-gray-600">
            Ready to assemble your startup dungeon? Match with co-founders, track progress, and launch.
          </p>
        </div>
        {/* Your matching UI here */}
      </div>
    </div>
  )
}
