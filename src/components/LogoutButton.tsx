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
      type="button"
      onClick={handleLogout}
      className="rounded-md border px-3 py-1 text-sm"
    >
      Logout
    </button>
  )
}