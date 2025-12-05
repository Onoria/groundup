'use client'

import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'

export default function Signup() {
  const supabase = createClient()

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center p-8">
      <div className="w-full max-w-md">
        <h1 className="text-5xl font-black text-center mb-12 bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-400">
          GroundUp
        </h1>
        <Auth
          supabaseClient={supabase}
          appearance={{ theme: ThemeSupa }}
          theme="dark"
          providers={[]}
          redirectTo="/onboarding/role"
          showLinks={false}
          onlyThirdPartyProviders={false} // THIS LINE WAS HIDING SIGN UP — REMOVED
        />
      </div>
    </div>
  )
}