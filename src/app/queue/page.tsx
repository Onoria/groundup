'use client'

import { createClient } from '@/lib/supabase'

export default async function Queue() {
  const supabase = createClient()
  const { data: { user } } = await supabase.auth.getUser()

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-white p-12">
      <div className="max-w-4xl mx-auto text-center">
        <h1 className="text-6xl font-black mb-8">You’re in the Queue!</h1>
        <div className="bg-slate-800/50 backdrop-blur rounded-2xl p-12 border border-slate-700">
          <p className="text-3xl mb-4">Current position:</p>
          <p className="text-8xl font-black text-emerald-400">#7</p>
          <p className="text-xl text-slate-300 mt-8">Estimated match time: <strong>4–9 days</strong></p>
          <p className="text-lg text-slate-400 mt-12">We’re matching you with 4 perfect co-founders based on role, experience, and vision.</p>
        </div>
      </div>
    </div>
  )
}