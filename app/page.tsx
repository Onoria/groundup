import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-slate-900 text-white relative overflow-hidden">
      {/* Subtle background pattern (no overlay breakage) */}
      <div className="absolute inset-0 opacity-10">
        <div className="absolute inset-0" style={{backgroundImage: 'radial-gradient(circle at 25% 25%, #3b82f6 0%, transparent 50%), radial-gradient(circle at 75% 75%, #10b981 0%, transparent 50%)'}} />
      </div>

      <header className="relative z-10 border-b border-white/10">
        <div className="max-w-6xl mx-auto px-6 py-6 flex justify-between items-center">
          <h1 className="text-2xl font-bold text-cyan-400">GroundUp</h1>
          <div className="flex items-center gap-6">
            <SignedOut>
              <SignInButton mode="modal">
                <button className="text-gray-300 hover:text-white transition text-sm font-medium">Sign in</button>
              </SignInButton>
            </SignedOut>
            <SignedIn>
              <UserButton afterSignOutUrl="/" />
            </SignedIn>
          </div>
        </div>
      </header>

      <main className="relative z-10 max-w-6xl mx-auto pt-32 px-6">
        <div className="text-center mb-16">
          <h2 className="heading-1">
            Prove your skills privately with zero-knowledge proofs.
          </h2>
          <p className="text-muted max-w-3xl mx-auto mb-12">
            Form balanced founding teams for tech startups or blue-collar empires. 
            Incorporate in week one. Hire verified American labor. Build real companies from the ground up.
          </p>
        </div>

        <div className="flex flex-col md:flex-row gap-8 justify-center mb-20">
          <SignedIn>
            <Link href="/match">
              <button className="btn-secondary">Join the Waitlist – $49/mo</button>
            </Link>
          </SignedIn>
          <SignedOut>
            <SignInButton mode="modal">
              <button className="btn-primary">Get Started</button>
            </SignInButton>
          </SignedOut>
          <Link href="/how-it-works">
            <button className="btn-primary text-sm px-6 py-3">See How It Works</button>
          </Link>
        </div>

        {/* Early access card with glassmorphism */}
        <div className="glass-card max-w-md mx-auto mb-20 p-6 text-center">
          <h3 className="heading-2">Get Early Access</h3>
          <form className="space-y-4">
            <input
              type="email"
              placeholder="your@email.com"
              className="w-full px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-400"
            />
            <button type="submit" className="btn-secondary w-full">
              Join Waitlist – First Month 50% Off
            </button>
          </form>
          <p className="text-xs text-gray-500 mt-4">
            Limited spots. Matching starts January 2026.
          </p>
        </div>

        {/* How it works section with glass cards */}
        <div className="text-center">
          <h3 className="heading-2 mb-12">How GroundUp Works</h3>
          <div className="grid md:grid-cols-3 gap-8 max-w-4xl mx-auto">
            <div className="glass-card p-6">
              <div className="text-4xl font-bold text-cyan-400 mb-4">1</div>
              <h4 className="text-xl font-semibold mb-2">Verify Privately</h4>
              <p className="text-muted">Zero-knowledge proofs confirm skills without revealing details.</p>
            </div>
            <div className="glass-card p-6">
              <div className="text-4xl font-bold text-cyan-400 mb-4">2</div>
              <h4 className="text-xl font-semibold mb-2">Match & 21-Day Chemistry</h4>
              <p className="text-muted">AI forms balanced teams; trial period ensures fit.</p>
            </div>
            <div className="glass-card p-6">
              <div className="text-4xl font-bold text-cyan-400 mb-4">3</div>
              <h4 className="text-xl font-semibold mb-2">Incorporate & Execute</h4>
              <p className="text-muted">Legal templates + progress tracking for your state/industry.</p>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
