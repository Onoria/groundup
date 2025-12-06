'use client'

export const dynamic = 'force-dynamic'

import { useUser } from '@clerk/nextjs'
import { useState, useEffect } from 'react'
import { setQueued } from '../lib/updateMetadata'
import Link from 'next/link'

export default function Match() {
  const { user, isLoaded } = useUser()
  const [isQueued, setIsQueued] = useState(false)

  useEffect(() => {
    if (user?.publicMetadata?.queued === true) setIsQueued(true)
  }, [user])

  if (!isLoaded || !user) return <div className="flex min-h-screen items-center justify-center">Loading...</div>

  const role = (user.publicMetadata as any)?.role || 'Hero'

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-4xl font-bold mb-8">Dungeon Finder: {role} Queue</h1>
        <p className="text-xl mb-6">Waiting for a balanced party. Monthly sub unlocks instant matches.</p>

        {!isQueued ? (
          <form action={async () => {
            await setQueued(true)
            setIsQueued(true)
          }}>
            <button type="submit" className="px-8 py-4 bg-green-600 text-white rounded-lg font-semibold">
              Join Queue as {role}
            </button>
          </form>
        ) : (
          <p className="text-green-600 mb-8">You’re in the queue! <Link href="/dashboard" className="underline">Back to dashboard</Link></p>
        )}

        <div className="mt-8 text-center">
          <Link href="/subscribe" className="px-8 py-4 bg-blue-600 text-white rounded-lg font-semibold">
            Subscribe ($29/mo) for Unlimited Matches
          </Link>
        </div>
      </div>
    </div>
  )
}
