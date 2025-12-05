'use client'

import { SignedIn, SignedOut, UserButton, RedirectToSignIn } from '@clerk/nextjs'
import Link from 'next/link'

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-gradient-to-b from-gray-900 to-black text-white px-8">
      <h1 className="text-5xl md:text-6xl font-bold mb-6 text-center">
        GroundUp
      </h1>
      <p className="text-xl md:text-2xl text-center max-w-2xl mb-12 text-gray-300">
        The Dungeon Finder for real startups. Get matched with co-founders, schedule your first war-room, 
        and track incorporation & funding milestones — all in one place.
      </p>

      <SignedOut>
        <div className="space-x-4">
          <Link
            href="/sign-up"
            className="px-8 py-4 bg-blue-600 hover:bg-blue-700 rounded-lg text-lg font-semibold transition"
          >
            Start Your Quest → Subscribe
          </Link>
          <Link href="/sign-in" className="text-gray-400 hover:text-white">
            Already have an account?
          </Link>
        </div>
      </SignedOut>

      <SignedIn>
        <div className="flex flex-col items-center gap-6">
          <p className="text-2xl">Welcome back, hero!</p>
          <Link
            href="/match"
            className="px-8 py-4 bg-green-600 hover:bg-green-700 rounded-lg text-lg font-semibold"
          >
            Find Your Party
          </Link>
          <UserButton afterSignOutUrl="/" />
        </div>
      </SignedIn>
    </main>
  )
}
