'use client'

import { useState } from 'react'
import { setQueued } from '@/lib/updateMetadata'
import { UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function MatchPage() {
  const [isQueued, setIsQueued] = useState(false)
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const joinPool = async () => {
    setError(null); setIsPending(true)
    try { await setQueued(true); setIsQueued(true) }
    catch { setError('Failed to join — please try again') }
    finally { setIsPending(false) }
  }

  const leavePool = async () => {
    setError(null); setIsPending(true)
    try { await setQueued(false); setIsQueued(false) }
    finally { setIsPending(false) }
  }

  return (
    <div className="min-h-screen bg-[#0a0a0a] text-white">
      <header className="border-b border-white/10">
        <div className="max-w-6xl mx-auto px-6 py-6 flex justify-between items-center">
          <Link href="/" className="text-xl font-semibold">GroundUp</Link>
          <UserButton afterSignOutUrl="/" />
        </div>
      </header>

      <main className="max-w-2xl mx-auto pt-32 px-6 text-center">
        <h1 className="text-5xl font-light tracking-tight mb-12">
          Ready to meet your co-founders?
        </h1>

        {error && (
          <div className="mb-10 bg-red-900/20 border border-red-800 text-red-400 px-8 py-5 rounded-2xl">
            {error}
          </div>
        )}

        {!isQueued ? (
          <button
            onClick={joinPool}
            disabled={isPending}
            className="bg-white hover:bg-gray-100 disabled:opacity-50 text-black font-medium text-xl px-16 py-6 rounded-2xl transition transform hover:scale-105"
          >
            {isPending ? 'Joining...' : 'Join Matching Pool'}
          </button>
        ) : (
          <div className="space-y-8">
            <div className="text-3xl text-gray-300">
              You’re in the matching pool
            </div>
            <button
              onClick={leavePool}
              disabled={isPending}
              className="text-gray-500 hover:text-white underline transition"
            >
              Leave pool
            </button>
          </div>
        )}
      </main>
    </div>
  )
}
