'use client'  // Client for Auth UI interactivity

import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function Signup() {
  const supabase = createClient()
  const router = useRouter()

  useEffect(() => {
    // Redirect if already signed in
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_IN' && session) {
        router.replace('/onboarding/role')
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
            redirectTo={`${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`}
            showLinks={true}  // Enables "Already have an account? Sign in"
            providers={[]}
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
        <p className="text-center text-zinc-500 mt-8 text-sm">
          By continuing you agree to our Terms and Privacy Policy
        </p>
      </div>
    </div>
  )
}