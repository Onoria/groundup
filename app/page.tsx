import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="min-h-screen bg-[#0a0a0a] text-white">
      <header className="border-b border-white/10">
        <div className="max-w-6xl mx-auto px-6 py-6 flex justify-between items-center">
          <h1 className="text-2xl font-semibold tracking-tight">GroundUp</h1>
          <div className="flex items-center gap-6">
            <SignedOut>
              <SignInButton mode="modal">
                <button className="text-gray-400 hover:text-white transition">Sign in</button>
              </SignInButton>
            </SignedOut>
            <SignedIn>
              <UserButton afterSignOutUrl="/" />
            </SignedIn>
          </div>
        </div>
      </header>

      <main className="max-w-5xl mx-auto pt-32 px-6 text-center">
        <h2 className="text-6xl md:text-7xl font-light tracking-tight mb-8 leading-tight">
          Find Your<br />Co-Founder Team
        </h2>
        <p className="text-xl md:text-2xl text-gray-400 mb-16 max-w-3xl mx-auto leading-relaxed">
          One technical founder. One growth lead. One operator.<br />
          Matched instantly. No noise. No endless intros.
        </p>

        <div className="flex flex-col items-center gap-8">
          <SignedIn>
            <Link href="/match">
              <button className="bg-white hover:bg-gray-100 text-black font-medium text-lg px-12 py-5 rounded-2xl transition transform hover:scale-105">
                Start Matching
              </button>
            </Link>
          </SignedIn>

          <SignedOut>
            <SignInButton mode="modal">
              <button className="bg-white hover:bg-gray-100 text-black font-medium text-lg px-12 py-5 rounded-2xl transition transform hover:scale-105">
                Get Started
              </button>
            </SignInButton>
          </SignedOut>

          <p className="text-sm text-gray-500">
            Paid members get priority matching + scheduled calls within 24h
          </p>
        </div>
      </main>
    </div>
  )
}
