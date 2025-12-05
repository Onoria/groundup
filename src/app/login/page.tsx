// src/app/login/page.tsx
'use client'

import { useEffect, useMemo } from 'react'
import { useRouter } from 'next/navigation'
import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'

export default function Login() {
  const router = useRouter()
  const supabase = useMemo(() => createClient(), [])

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) {
        router.replace('/onboarding/role')
        router.refresh()
      }
    })
  }, [router, supabase])

  const redirectTo =
    typeof window === 'undefined'
      ? undefined
      : `${window.location.origin}/auth/callback`

  return (
    <div className="mx-auto flex max-w-md flex-col gap-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Log in to GroundUp</h1>
      </header>

      <Auth
        supabaseClient={supabase}
        view="magic_link"
        appearance={{ theme: ThemeSupa }}
        showLinks={false}
        providers={[]}
        redirectTo={redirectTo}
      />
    </div>
  )
}