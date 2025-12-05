// src/components/LogoutButton.tsx
'use client'

import { createClient } from '@/lib/supabase'
import { useRouter } from 'next/navigation'

export default function LogoutButton() {
  const router = useRouter()
  const supabase = createClient()

  const handleLogout = async () => {
    await supabase.auth.signOut()
    router.push('/')
    router.refresh()
  }

  return (
    <button
      onClick={handleLogout}
      className="px-6 py-2 bg-zinc-800 hover:bg-zinc-700 rounded-lg text-sm font-medium transition"
    >
      Logout
    </button>
  )
}