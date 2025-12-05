// src/app/signup/page.tsx
'use client'

import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'
import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'

export default function Signup() {
  const supabase = createClient()
  const router = useRouter()
  const [emailSent, setEmailSent] = useState(false)

  // Only listen for actual sign-in
  useEffect(() => {
    const { data: listener } = supabase.auth.onAuthStateChange((event, session) => {
      if (session) router.replace('/onboarding/role')
    })
    return () => listener.subscription.unsubscribe()
  }, [router, supabase])

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center p-8">
      <div className="w-full max-w-md">
        <h1 className="text-center text-6xl font-black text-emerald-400 mb-12">GroundUp</h1>

        {emailSent ? (
          <div className="text-center">
            <p className="text-2xl text-white mb-8">Check your email for the magic link</p>
            <div className="animate-spin w-16 h-16 border-4 border-emerald-500 border-t-transparent rounded-full mx-auto" />
            <p className="text-gray-400 mt-8 text-sm">No email? Check spam or try again.</p>
          </div>
        ) : (
          <div className="bg-zinc-900/50 backdrop-blur rounded-2xl p-8 border border-zinc-800">
            {/* Hidden Auth UI — does the real magic-link request */}
            <div className="opacity-0 h-0 overflow-hidden">
              <Auth
                supabaseClient={supabase}
                view="magic_link"
                showLinks={false}
                providers={[]}
                redirectTo={`${process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`}
                appearance={{ theme: ThemeSupa }}
                theme="dark"
              />
            </div>

            {/* Custom beautiful form */}
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const email = (e.currentTarget.elements.namedItem('email') as HTMLInputElement).value.trim()
                if (!email) return

                // Trigger the hidden Auth form → sends magic link + instantly flips UI
                const hiddenEmailInput = document.querySelector('input[type="email"]') as HTMLInputElement
                if (hiddenEmailInput) {
                  hiddenEmailInput.value = email
                  hiddenEmailInput.form?.requestSubmit()
                  setEmailSent(true) // Immediately show spinner
                }
              }}
              className="space-y-6"
            >
              <input
                name="email"
                type="email"
                required
                placeholder="you@company.com"
                className="w-full px-6 py-4 bg-zinc-800 border border-zinc-700 rounded-xl text-white text-lg placeholder-zinc-500 focus:outline-none focus:border-emerald-500 transition"
              />
              <button
                type="submit"
                className="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-5 rounded-xl text-lg transition"
              >
                Send Magic Link
              </button>
            </form>
          </div>
        )}
      </div>
    </div>
  )
}