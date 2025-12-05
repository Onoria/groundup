// src/app/signup/page.tsx
'use client'

import { useEffect, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'

export default function Signup() {
  const router = useRouter()
  const supabase = useMemo(() => createClient(), [])

  useEffect(() => {
    // Initial session check — handles returning users and the case where the
    // magic link opens in a different tab but this tab has already picked up
    // the session via cookies.
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) {
        router.replace('/onboarding/role')
        router.refresh()
      }
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_IN' && session) {
        router.replace('/onboarding/role')
        router.refresh()
      }
    })

    return () => {
      subscription.unsubscribe()
    }
  }, [router, supabase])

  const redirectTo =
    typeof window === 'undefined'
      ? undefined
      : `${window.location.origin}/auth/callback`

  return (
    <div className="mx-auto flex max-w-md flex-col gap-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">GroundUp</h1>
        <p className="text-sm text-gray-500">
          Form balanced founding teams for tech startups or blue-collar empires.
        </p>
      </header>

      <Auth
        supabaseClient={supabase}
        view="magic_link"
        appearance={{ theme: ThemeSupa }}
        showLinks={false}
        providers={[]}
        redirectTo={redirectTo}
      />

      <p className="text-xs text-gray-500">
        By continuing you agree to our Terms and Privacy Policy.
      </p>
    </div>
  )
}