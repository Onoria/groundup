'use client'

import { useState } from 'react'
import { setQueued } from '@/lib/updateMetadata'
import { UserButton, useUser } from '@clerk/nextjs'
import Link from 'next/link'

export default function MatchPage() {
  const { user } = useUser()
  const [isQueued, setIsQueued] = useState(false)
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const joinPool = async () => {
    setError(null)
    setIsPending(true)
    try {
      await setQueued(true)
      setIsQueued(true)
    } catch (err: any) {
      setError('Failed to join — please try again')
    } finally {
      setIsPending(false)
    }
  }

  const leavePool = async () => {
    setError(null)
    setIsPending(true)
    try {
      await setQueued(false)
      setIsQueued(false)
    } finally {
      setIsPending(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="border-b bg-white">
        <div className="max-w-6xl mx-auto px-6 py-5 flex justify-between items-center">
          <Link href="/" className="text-xl font-semibold">GroundUp</Link>
          <UserButton afterSignOutUrl="/" />
        </div>
      </header>

      <main className="max-w-2xl mx-auto pt-24 px-6 text-center">
        <h1 className="text-4xl font-light tracking-tight text-gray-900 mb-6">
          Ready to meet your co-founders?
        </h1>

        {error && (
          <div className="mb-8 bg-red-50 border border-red-200 text-red-700 px-6 py-4 rounded-lg">
            {error}
          </div>
        )}

        {!isQueued ? (
          <button
            onClick={joinPool}
            disabled={isPending}
            className="bg-black hover:bg-gray-800 disabled:opacity-50 text-white font-medium text-lg px-12 py-5 rounded-xl transition"
          >
            {isPending ? 'Joining pool...' : 'Join Matching Pool'}
          </button>
        ) : (
          <div>
            <p className="text-2xl text-gray-800 mb-8">
              You’re in the matching pool
            </p>
            <button
              onClick={leavePool}
              disabled={isPending}
              className="text-gray-600 underline hover:text-black"
            >
              Leave pool
            </button>
          </div>
        )}
      </main>
    </div>
  )
}
