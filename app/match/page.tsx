'use client'

import { useState } from 'react'
import { setQueued } from '@/lib/updateMetadata'

export default function MatchPage() {
  const [isQueued, setIsQueued] = useState(false)
  const [isPending, setIsPending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const joinQueue = async () => {
    setError(null)
    setIsPending(true)
    try {
      await setQueued(true)
      setIsQueued(true)
    } catch (err: any) {
      setError(err.message || 'Something went wrong – please try again')
    } finally {
      setIsPending(false)
    }
  }

  const leaveQueue = async () => {
    setError(null)
    setIsPending(true)
    try {
      await setQueued(false)
      setIsQueued(false)
    } catch (err: any) {
      setError(err.message || 'Something went wrong – please try again')
    } finally {
      setIsPending(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto pt-20 text-center">
      <h1 className="text-4xl font-bold mb-8">Find Your Startup Team</h1>

      {error && (
        <div className="bg-red-100 border border-red-400 text-red-700 px-6 py-4 rounded mb-8 max-w-md mx-auto">
          {error}
        </div>
      )}

      {!isQueued ? (
        <button
          onClick={joinQueue}
          disabled={isPending}
          className="bg-green-600 hover:bg-green-700 disabled:opacity-50 text-white font-bold py-6 px-12 rounded text-2xl transition"
        >
          {isPending ? 'Joining Queue...' : 'Join the Queue'}
        </button>
      ) : (
        <div>
          <p className="text-3xl mb-6">✅ You are in the queue!</p>
          <button
            onClick={leaveQueue}
            disabled={isPending}
            className="bg-gray-600 hover:bg-gray-700 text-white font-bold py-4 px-10 rounded"
          >
            Leave Queue
          </button>
        </div>
      )}
    </div>
  )
}
