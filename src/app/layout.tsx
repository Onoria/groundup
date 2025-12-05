// src/app/layout.tsx
import './globals.css'
import { createServerSupabaseClient } from '@/lib/supabase/server'
import Link from 'next/link'
import LogoutButton from '@/components/LogoutButton'

export const dynamic = 'force-dynamic'

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = createServerSupabaseClient()
  const { data: { session } } = await supabase.auth.getSession()

  return (
    <html lang="en" className="h-full">
      <body className="h-full bg-black text-white">
        <div className="min-h-screen flex flex-col">
          <header className="border-b border-zinc-800">
            <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
              <Link
                href="/"
                className="text-4xl font-black text-emerald-400 hover:text-emerald-300 transition"
              >
                GroundUp
              </Link>

              {session && <LogoutButton />}
            </div>
          </header>

          <main className="flex-1">
            {children}
          </main>
        </div>
      </body>
    </html>
  )
}