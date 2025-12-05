// src/app/signup/page.tsx
'use client'

import { useEffect, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'

export default function SignupPage() {
  const router = useRouter()
  const supabase = useMemo(() => createClient(), [])

  useEffect(() => {
    const {
      data: { subscription }
    } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) {
        router.replace('/welcome')
      }
    })

    return () => subscription.unsubscribe()
  }, [router, supabase])

  const redirectTo =
    typeof window === 'undefined'
      ? undefined
      : `${window.location.origin}/auth/callback`

  return (
    <div className="max-w-md mx-auto flex flex-col gap-6">
      <h1 className="text-2xl font-semibold">Sign Up</h1>

      <Auth
        supabaseClient={supabase}
        appearance={{ theme: ThemeSupa }}
        view="magic_link"
        showLinks={false}
        providers={[]}
        redirectTo={redirectTo}
      />
    </div>
  )
}
