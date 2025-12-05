'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'

export default function RoleRedirect() {
  const router = useRouter()
  const supabase = createClient()

  useEffect(() => {
    // Force redirect to the real role selection screen
    router.replace('/onboarding/role/selection')
  }, [router])

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center">
      <p className="text-white text-xl">Redirecting to role selection...</p>
    </div>
  )
}