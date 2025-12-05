// src/app/welcome/page.tsx
import Link from 'next/link'

export default function Welcome() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-black flex items-center justify-center p-8">
      <div className="text-center max-w-md">
        <h1 className="text-6xl font-black text-emerald-400 mb-8">Welcome to GroundUp</h1>
        <p className="text-xl text-zinc-300 mb-12">
          Thanks for signing up! You're now logged in and ready to assemble your co-founder raid party.
        </p>
        <div className="space-y-6">
          <Link
            href="/onboarding/role"
            className="inline-block w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-4 px-10 rounded-xl text-lg transition"
          >
            Go to Role Selection →
          </Link>
          <p className="text-sm text-zinc-500">
            Your main tab is already logged in and waiting.<br />
            <strong>You can close this window now.</strong>
          </p>
        </div>
      </div>
    </div>
  )
}