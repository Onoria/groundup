import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-blue-950 to-slate-950 text-white overflow-hidden relative">
      <div className="absolute inset-0 bg-gradient-to-t from-black/50 via-transparent to-transparent" />
      
      <header className="relative z-10 border-b border-white/10 backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-6 py-6 flex justify-between items-center">
          <h1 className="heading-cyan">GroundUp</h1>
          <div className="flex items-center gap-8">
            <SignedOut>
              <SignInButton mode="modal">
                <button className="text-gray-300 hover:text-white transition font-medium">Sign in</button>
              </SignInButton>
            </SignedOut>
            <SignedIn>
              <UserButton afterSignOutUrl="/" />
            </SignedIn>
          </div>
        </div>
      </header>

      <main className="relative z-10 max-w-5xl mx-auto pt-24 px-6 text-center">
        <h2 className="text-5xl md:text-6xl font-light text-gray-300 mb-6">
          Prove your skills privately with zero-knowledge proofs.
        </h2>
        <p className="text-2xl text-gray-400 mb-12 max-w-4xl mx-auto leading-relaxed">
          Form balanced founding teams for tech startups or blue-collar empires.<br />
          Incorporate in week one. Hire verified American labor. Build real companies from the ground up.
        </p>

        <div className="flex flex-col sm:flex-row gap-6 justify-center items-center mb-20">
          <SignedIn>
            <Link href="/match">
              <button className="btn-success text-xl px-12">Join the Waitlist – $49/mo</button>
            </Link>
          </SignedIn>
          <SignedOut>
            <SignInButton mode="modal">
              <button className="btn-primary text-xl px-12">Get Early Access</button>
            </SignInButton>
          </SignedOut>
          <button className="btn-primary opacity-80 hover:opacity-100 text-lg px-10">See How It Works</button>
        </div>

        <div className="glass max-w-lg mx-auto p-8 mb-20">
          <h3 className="text-3xl font-bold text-cyan-400 mb-6">Get Early Access</h3>
          <input
            type="email"
            placeholder="your@email.com"
            className="w-full px-6 py-4 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-500 mb-4"
          />
          <button className="w-full btn-success">Join Waitlist – First Month 50% Off</button>
          <p className="text-sm text-gray-500 mt-4">Limited spots. Matching starts January 2026.</p>
        </div>

        <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          {[
            { num: "1", title: "Verify Privately", desc: "Zero-knowledge proofs confirm skills without revealing details." },
            { num: "2", title: "Match & 21-Day Chemistry", desc: "AI forms balanced teams; trial period ensures perfect fit." },
            { num: "3", title: "Incorporate & Execute", desc: "Legal templates + progress tracking for your state/industry." },
          ].map((step) => (
            <div key={step.num} className="glass p-8 text-center">
              <div className="text-6xl font-bold text-cyan-400 mb-4">{step.num}</div>
              <h4 className="text-2xl font-semibold mb-3">{step.title}</h4>
              <p className="text-gray-400">{step.desc}</p>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}
