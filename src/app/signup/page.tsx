'use client'

import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function Signup() {
  const supabase = createClient()
  const router = useRouter()

  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (session) {
        // Force full page reload to clear any cached state
        window.location.href = '/onboarding/role'
      }
    })

    return () => subscription.unsubscribe()
  }, [router, supabase])

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center p-6">
      <div className="w-full max-w-md">
        <h1 className="text-center text-6xl font-black text-emerald-400 mb-12 tracking-tighter">
          GroundUp
        </h1>
        <div className="bg-zinc-900/90 backdrop-blur-xl rounded-3xl p-10 border border-zinc-800 shadow-2xl">
          <Auth
            supabaseClient={supabase}
            view="magic_link"
            onlyThirdPartyProviders={false}
            showLinks={false}
            providers={[]}
            redirectTo={`${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`}
            magicLink={true}
            theme="dark"
            appearance={{
              theme: ThemeSupa,
              variables: {
                default: {
                  colors: {
                    brand: '#10b981',
                    brandAccent: '#059669',
                  },
                },
              },
            }}
          />
        </div>
      </div>
    </div>
  )
}