// src/app/layout.tsx
import './globals.css'

import Link from 'next/link'
import LogoutButton from '@/components/LogoutButton'
import { createServerSupabaseClient } from '@/lib/supabase/server'
import type { ReactNode } from 'react'

export const dynamic = 'force-dynamic'

export default async function RootLayout({
  children,
}: {
  children: ReactNode
}) {
  const supabase = await createServerSupabaseClient()
  const {
    data: { session },
  } = await supabase.auth.getSession()

  return (
    <html lang="en">
      <body>
        <header className="border-b">
          <nav className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
            <Link href="/" className="font-semibold">
              GroundUp
            </Link>
            <div className="flex items-center gap-3 text-sm">
              {session ? (
                <>
                  <span className="text-gray-500">
                    {session.user.email ?? 'Signed in'}
                  </span>
                  <LogoutButton />
                </>
              ) : (
                <>
                  <Link href="/signup">Sign up</Link>
                  <Link href="/login">Log in</Link>
                </>
              )}
            </div>
          </nav>
        </header>
        <main className="mx-auto max-w-5xl px-4 py-8">{children}</main>
      </body>
    </html>
  )
}