import { createClient } from '@/lib/supabase/server'
import Link from 'next/link'
import LogoutButton from '@/components/LogoutButton'
import type { ReactNode } from 'react'

export const dynamic = 'force-dynamic'

export default async function RootLayout({
  children,
}: {
  children: ReactNode
}) {
  const supabase = createClient()
  const {
    data: { session },
  } = await supabase.auth.getSession()

  return (
    <html lang="en">
      <body className="min-h-screen bg-gray-50">
        <nav className="bg-white shadow-sm">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between h-16">
              <div className="flex items-center">
                <Link href="/" className="text-xl font-bold text-gray-900">
                  GroundUp
                </Link>
              </div>
              <div className="flex items-center space-x-4">
                {session ? (
                  <LogoutButton />
                ) : (
                  <Link href="/signin" className="text-gray-700 hover:text-gray-900">
                    Sign in
                  </Link>
                )}
              </div>
            </div>
          </div>
        </nav>
        <main>{children}</main>
      </body>
    </html>
  )
}
