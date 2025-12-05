'use client'

import { Auth } from '@supabase/auth-ui-react'
import { ThemeSupa } from '@supabase/auth-ui-shared'
import { createClient } from '@/lib/supabase'

export default function Signup() {
  const supabase = createClient()

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-900">
      <div className="w-full max-w-md">
        <h1 className="mb-8 text-center text-4xl font-bold text-white">GroundUp</h1>
        <div className="rounded-lg bg-gray-800 p-8 shadow-xl">
          <Auth
            supabaseClient={supabase}
            view="magic_link"
            appearance={{ theme: ThemeSupa }}
            theme="dark"
            showLinks={true}
            providers={[]}
            redirectTo="http://localhost:3000/onboarding/role"
          />
        </div>
      </div>
    </div>
  )
}