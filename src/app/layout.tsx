// src/app/layout.tsx
import './globals.css'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import Link from 'next/link'
import LogoutButton from '@/components/LogoutButton'

export const dynamic = 'force-dynamic'

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const cookieStore = await cookies()
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value
        },
        set(name: string, value: string, options?: any) {
          cookieStore.set(name, value, options)
        },
        remove(name: string, options?: any) {
          cookieStore.delete(name)
        },
      },
    }
  )
  const { data: { session } } = await supabase.auth.getSession()

  return (
    <html lang="en" className="h-full">
      <body className="h-full bg-black text-white">
        <div className="min-h-screen flex flex-col">
          {/* Header */}
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

          {/* Main Content */}
          <main className="flex-1">
            {children}
          </main>
        </div>
      </body>
    </html>
  )
}