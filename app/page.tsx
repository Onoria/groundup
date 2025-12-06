import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="min-h-screen relative overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-br from-slate-950 via-blue-950 to-slate-950" />
      
      <header className="relative z-10 border-b border-white/10 backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-6 py-6 flex justify-between items-center">
          <h1 className="heading">GroundUp</h1>
          <div className="flex items-center gap-8">
            <SignedOut>
              <SignInButton mode="modal">
                <button className="text-gray-300 hover:text-white font-medium transition">Sign in</button>
              </SignInButton>
            </SignedOut>
            <SignedIn>
              <UserButton afterSignOutUrl="/" />
            </SignedIn>
          </div>
        </div>
      </header>

      <main className="relative z-10 max-w-6xl mx-auto px-6 pt-32 text-center">
        <p className="text-3xl text-gray-300 mb-6 font-light">
          Prove your skills privately with zero-knowledge proofs.
        </p>
        <p className="text-2xl text-gray-400 mb-16 max-w-4xl mx-auto">
          Form balanced founding teams for tech startups or blue-collar empires.<br />
          Incorporate in week one. Hire verified American labor. Build real companies from the ground up.
        </p>

        <div className="flex flex-col sm:flex-row gap-6 justify-center mb-20">
          <SignedIn>
            <Link href="/match">
              <button className="btn-green">Join the Waitlist – $49/mo</button>
            </Link>
          </SignedIn>
          <SignedOut>
            <SignInButton mode="modal">
              <button className="btn-green">Get Early Access</button>
            </SignInButton>
          </SignedOut>
          <button className="btn-green opacity-80">See How It Works</button>
        </div>

        <div className="glass max-w-md mx-auto p-10 mb-20">
          <h3 className="text-3xl font-bold text-cyan-400 mb-6">Get Early Access</h3>
          <input
            type="email"
            placeholder="your@email.com"
            className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-xl text-white placeholder-gray-500 mb-4"
          />
          <button className="w-full btn-green">Join Waitlist – First Month 50% Off</button>
          <p className="text-sm text-gray-500 mt-4">Limited spots. Matching starts January 2026.</p>
        </div>

        <div className="grid md:grid-cols-3 gap-10">
          {[
            { n: "1", title: "Verify Privately", desc: "Zero-knowledge proofs confirm skills without revealing details." },
            { n: "2", title: "Match & 21-Day Chemistry", desc: "AI forms balanced teams; trial period ensures perfect fit." },
            { n: "3", title: "Incorporate & Execute", desc: "Legal templates + progress tracking for your state/industry." },
          ].map(s => (
            <div key={s.n} className="glass p-10 text-center">
              <div className="text-6xl font-bold text-cyan-400 mb-4">{s.n}</div>
              <h4 className="text-2xl font-semibold mb-4">{s.title}</h4>
              <p className="text-gray-400">{s.desc}</p>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}
