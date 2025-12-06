import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="min-h-screen bg-white">
      <header className="border-b border-gray-100">
        <div className="max-w-6xl mx-auto px-6 py-5 flex justify-between items-center">
          <h1 className="text-2xl font-semibold tracking-tight">GroundUp</h1>
          <div className="flex items-center gap-6">
            <SignedOut>
              <SignInButton mode="modal">
                <button className="text-gray-700 hover:text-black font-medium">Sign in</button>
              </SignInButton>
            </SignedOut>
            <SignedIn>
              <UserButton afterSignOutUrl="/" />
            </SignedIn>
          </div>
        </div>
      </header>

      <main className="max-w-4xl mx-auto pt-32 px-6 text-center">
        <h2 className="text-5xl md:text-6xl font-light tracking-tight text-gray-900 mb-8">
          Find Your Co-Founder Team
        </h2>
        <p className="text-xl text-gray-600 mb-12 max-w-2xl mx-auto">
          One technical founder. One growth lead. One operator.<br />
          Matched instantly. No endless swiping. No coffee chats that go nowhere.
        </p>

        <SignedIn>
          <Link href="/match">
            <button className="bg-black hover:bg-gray-800 text-white font-medium text-lg px-10 py-4 rounded-xl transition">
              Start Matching
            </button>
          </Link>
        </SignedIn>

        <SignedOut>
          <SignInButton mode="modal">
            <button className="bg-black hover:bg-gray-800 text-white font-medium text-lg px-10 py-4 rounded-xl transition">
              Get Started
            </button>
          </SignInButton>
        </SignedOut>

        <p className="mt-12 text-sm text-gray-500">
          Paid members get priority matching + scheduled intro calls within 24h
        </p>
      </main>
    </div>
  )
}
