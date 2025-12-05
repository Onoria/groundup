'use client'

import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'

export default function Signup() {
  const supabase = createClient()

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center px-6">
      <div className="max-w-md w-full bg-slate-800/50 backdrop-blur rounded-2xl p-10 border border-slate-700">
        <h1 className="text-4xl font-black text-center mb-8 bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-400">
          GroundUp
        </h1>
        <Auth
          supabaseClient={supabase}
          appearance={{ theme: ThemeSupa }}
          theme="dark"
          providers={[]}
          redirectTo="/onboarding/role"   // ← CORRECT PATH
          showLinks={false}
        />
      </div>
    </div>
  )
}