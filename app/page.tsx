import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#0a0f1c] via-[#111827] to-[#1e293b] text-white relative overflow-hidden">
      {/* Glow effects */}
      <div className="absolute inset-0 bg-gradient-to-t from-cyan-900/10 via-transparent to-emerald-900/10" />
      <div className="absolute top-20 left-20 w-96 h-96 bg-cyan-500/20 rounded-full blur-3xl" />
      <div className="absolute bottom-20 right-20 w-96 h-96 bg-emerald-500/20 rounded-full blur-3xl" />

      <header className="relative z-10 px-8 py-8">
        <div className="max-w-7xl mx-auto flex justify-between items-center">
          <div className="w-48" /> {/* Left spacer */}
          <div className="text-center">
            <h1 className="text-7xl md:text-8xl font-black bg-gradient-to-r from-cyan-400 via-cyan-300 to-emerald-400 bg-clip-text text-transparent">
              GroundUp
            </h1>
            <p className="text-cyan-300 text-xl mt-3 font-light">Prove skills. Form teams. Build empires.</p>
          </div>
          <div className="flex items-center justify-end w-48">
            <SignedOut>
              <SignInButton mode="modal">
                <button className="text-gray-400 hover:text-cyan-300 transition font-medium">Sign in</button>
              </SignInButton>
            </SignedOut>
            <SignedIn>
              <UserButton afterSignOutUrl="/" />
            </SignedIn>
          </div>
        </div>
      </header>

      <main className="relative z-10 max-w-6xl mx-auto px-8 pt-16 text-center">
        <p className="text-3xl text-cyan-200 font-light mb-6">
          Prove your skills privately with zero-knowledge proofs.
        </p>
        <p className="text-xl text-gray-400 mb-20 leading-relaxed max-w-4xl mx-auto">
          Form balanced founding teams for tech startups or blue-collar empires.<br />
          Incorporate in week one. Hire verified American labor. Build real companies from the ground up.
        </p>

        <div className="flex justify-center gap-8 mb-24">
          <SignedIn>
            <Link href="/match">
              <button className="bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 text-white font-bold px-12 py-6 rounded-2xl text-xl shadow-2xl shadow-emerald-500/50 transition-all hover:scale-105 hover:shadow-emerald-500/70">
                Join the Waitlist – $49/mo
              </button>
            </Link>
          </SignedIn>
          <SignedOut>
            <SignInButton mode="modal">
              <button className="bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 text-white font-bold px-12 py-6 rounded-2xl text-xl shadow-2xl shadow-emerald-500/50 transition-all hover:scale-105 hover:shadow-emerald-500/70">
                Get Early Access
              </button>
            </SignInButton>
          </SignedOut>
          <button className="bg-gradient-to-r from-cyan-500 to-cyan-600 hover:from-cyan-600 hover:to-cyan-700 text-white font-bold px-12 py-6 rounded-2xl text-xl shadow-2xl shadow-cyan-500/50 transition-all hover:scale-105 hover:shadow-cyan-500/70">
            See How It Works
          </button>
        </div>

        {/* Smaller Early Access Card — matches your red markup */}
        <div className="max-w-sm mx-auto mb-32"> {/* was max-w-md */}
          <div className="bg-white/10 backdrop-blur-2xl border border-white/20 rounded-3xl p-6 shadow-2xl"> {/* was p-8 */}
            <h3 className="text-3xl font-bold text-cyan-400 mb-4">Get Early Access</h3> {/* was mb-6 */}
            <input
              type="email"
              placeholder="your@email.com"
              className="w-full px-6 py-4 bg-white/10 border border-white/30 rounded-2xl text-white placeholder-gray-500 mb-4 focus:outline-none focus:ring-4 focus:ring-cyan-400/50"
            />
            <button className="w-full bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-600 hover:to-emerald-700 text-white font-bold py-4 rounded-2xl text-lg shadow-2xl shadow-emerald-500/50 transition-all hover:scale-105">
              Join Waitlist – First Month 50% Off
            </button>
            <p className="text-gray-500 text-xs mt-4">Limited spots. Matching starts January 2026.</p>
          </div>
        </div>

        <h2 className="text-5xl font-bold text-cyan-400 mb-16">How GroundUp Works</h2>

        <div className="grid md:grid-cols-3 gap-12 max-w-5xl mx-auto">
          {[
            { n: "1", title: "Verify Privately", desc: "Zero-knowledge proofs confirm skills without revealing details." },
            { n: "2", title: "Match & 21-Day Chemistry", desc: "AI forms balanced teams; trial period ensures perfect fit." },
            { n: "3", title: "Incorporate & Execute", desc: "Legal templates + progress tracking for your state/industry." },
          ].map((step) => (
            <div key={step.n} className="bg-white/10 backdrop-blur-2xl border border-white/20 rounded-3xl p-10 text-center shadow-2xl">
              <div className="text-7xl font-black text-cyan-400 mb-6">{step.n}</div>
              <h4 className="text-2xl font-bold mb-4">{step.title}</h4>
              <p className="text-gray-400 leading-relaxed">{step.desc}</p>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}
