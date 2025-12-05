// src/app/signup/page.tsx
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
    const { data: listener } = supabase.auth.onAuthStateChange((event, session) => {
      if (session) {
        router.replace('/onboarding/role')
      }
    })

    return () => listener.subscription.unsubscribe()
  }, [router, supabase])

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center p-8">
      <div className="w-full max-w-md">
        <h1 className="text-center text-6xl font-black text-emerald-400 mb-12">GroundUp</h1>

        {/* This is the magic — we KEEP the Auth component but hide it visually */}
        <div className="opacity-0 h-0 overflow-hidden">
          <Auth
            supabaseClient={supabase}
            view="magic_link"
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
            theme="dark"
            showLinks={false}
            providers={[]}
            redirectTo={`${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`}
          />
        </div>

        {/* Beautiful custom screen the user actually sees */}
        <div className="text-center">
          <p className="text-2xl text-white mb-8">Check your email for the magic link</p>
          <div className="animate-spin w-16 h-16 border-4 border-emerald-500 border-t-transparent rounded-full mx-auto" />
          <p className="text-gray-400 mt-8 text-sm">No email? Check spam or try again.</p>
        </div>
      </div>
    </div>
  )
}