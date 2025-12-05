'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'

export default function Signup() {
  const supabase = createClient()
  const router = useRouter()

  useEffect(() => {
    const { data: listener } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_IN') {
        router.replace('/onboarding/role')
        router.refresh()
      }
    })

    return () => listener.subscription.unsubscribe()
  }, [router, supabase])

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center p-8">
      <div className="max-w-md w-full text-center">
        <h1 className="text-6xl font-black text-emerald-400 mb-8">GroundUp</h1>
        <p className="text-2xl text-white mb-8">Creating your account...</p>
        <div className="animate-spin w-16 h-16 border-4 border-emerald-500 border-t-transparent rounded-full mx-auto" />
      </div>
    </div>
  )
}