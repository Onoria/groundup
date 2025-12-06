'use client'

import { useUser } from "@/src/lib/updateMetadata"
import { useState, useEffect } from "@/src/lib/updateMetadata"
import { updateQueueStatus } from "@/src/lib/updateMetadata"
import Link from "@/src/lib/updateMetadata"

export default function Match() {
  const { user, isLoaded } = useUser()
  const [isQueued, setIsQueued] = useState(false)

  useEffect(() => {
    if (user?.publicMetadata?.queued) setIsQueued(true)
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
            await updateQueueStatus(true)
            setIsQueued(true)
          }}>
            <button type="submit" className="px-8 py-4 bg-green-600 text-white rounded-lg font-semibold mb-8">
              Join Queue as {role}
            </button>
          </form>
        ) : (
          <p className="text-green-600 mb-8">You’re queued! <Link href="/dashboard" className="underline">Back to Progress</Link></p>
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
