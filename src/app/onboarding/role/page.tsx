'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function RoleRedirect() {
  const router = useRouter()

  useEffect(() => {
    // Optional: we can check session here later
    router.replace('/') // or go to real role selection later
  }, [router])

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-5xl font-black text-emerald-400 mb-4">Welcome to GroundUp!</h1>
        <p className="text-xl text-slate-300">You’re signed in. Redirecting...</p>
      </div>
    </div>
  )
}