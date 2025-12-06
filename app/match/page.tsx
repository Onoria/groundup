'use client'

import { useUser } from '@clerk/nextjs'
import { useState, useEffect } from 'react'
import Link from 'next/link'

export default function Match() {
  const { user, isLoaded } = useUser()
  const [queue, setQueue] = useState<string[]>([]) // Explicit type for TS
  const [isQueued, setIsQueued] = useState(false)

  useEffect(() => {
    if (user?.publicMetadata?.role) {
      setIsQueued(!!user.publicMetadata.queued) // Check metadata
      // Fetch queue from API or metadata aggregate (stub)
      setQueue(['Founder (NY, Senior, Fintech)', 'Developer (TX, Junior, SaaS)']) // Stub data
    }
  }, [user])

  if (!isLoaded) return <div className="flex min-h-screen items-center justify-center">Loading...</div>

  const joinQueue = async () => {
    // Update metadata: queued: true, timestamp
    await user.update({ publicMetadata: { ...user.publicMetadata, queued: true, queuedAt: Date.now() } })
    setIsQueued(true)
  }

  const role = user?.publicMetadata?.role || 'Hero'

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-4xl font-bold mb-8">Dungeon Finder: {role} Queue</h1>
        <p className="text-xl mb-6">Waiting for a balanced party (1 Founder + 1 Dev + 1 Designer + 1 Marketer). Monthly sub unlocks instant matches.</p>
        
        {!isQueued ? (
          <button onClick={joinQueue} className="px-8 py-4 bg-green-600 text-white rounded-lg font-semibold mb-8">
            Join Queue as {role}
          </button>
        ) : (
          <p className="text-green-600 mb-8">You're queued! We'll notify when your party forms. <Link href="/dashboard" className="underline">Back to Progress</Link></p>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {queue.map((entry, i) => (
            <div key={i} className="p-4 bg-white rounded-lg shadow">
              <h3 className="font-bold">{entry}</h3>
              <p className="text-sm text-gray-600">Looking for complementary roles...</p>
            </div>
          ))}
        </div>

        <div className="mt-8 text-center">
          <Link href="/subscribe" className="px-8 py-4 bg-blue-600 text-white rounded-lg font-semibold">
            Subscribe ($29/mo) for Unlimited Matches & Kickoff Scheduling
          </Link>
        </div>
      </div>
    </div>
  )
}
