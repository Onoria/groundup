'use client'

import './globals.css'
import { createClient } from '@/lib/supabase'
import { useEffect } from 'react'

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = createClient()

  const handleLogout = async () => {
    await supabase.auth.signOut()
    window.location.href = '/'
  }

  return (
    <html lang="en" className="h-full">
      <body className="h-full bg-gradient-to-b from-slate-950 to-slate-900 text-white">
        {/* Header with Logout */}
        <header className="fixed top-0 left-0 right-0 z-50 bg-slate-950/80 backdrop-blur border-b border-slate-800">
          <div className="container mx-auto px-6 py-4 flex justify-between items-center">
            <h1 className="text-2xl font-black bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-400">
              GroundUp
            </h1>
            <button
              onClick={handleLogout}
              className="px-6 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg border border-slate-700 transition text-sm font-medium"
            >
              Logout
            </button>
          </div>
        </header>

        {/* Main content — adds top padding so it’s not under the header */}
        <main className="pt-20 min-h-screen">
          {children}
        </main>
      </body>
    </html>
  )
}