import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="space-y-24 py-12">
      {/* Hero */}
      <section className="text-center">
        <h1 className="heading">GroundUp</h1>
        <p className="mt-6 text-xl text-cyan-300 font-light">Prove skills. Form teams. Build empires.</p>

        <p className="mt-12 text-3xl text-cyan-200 font-light">
          Prove your skills privately with zero-knowledge proofs.
        </p>
        <p className="mt-6 text-xl text-gray-400 max-w-4xl mx-auto leading-relaxed">
          Form balanced founding teams for tech startups or blue-collar empires.<br />
          Incorporate in week one. Hire verified American labor. Build real companies from the ground up.
        </p>

        <div className="mt-12 flex flex-wrap justify-center gap-6">
          <SignedIn>
            <Link href="/match">
              <button className="btn">Join the Waitlist – $49/mo</button>
            </Link>
          </SignedIn>
          <SignedOut>
            <SignInButton mode="modal">
              <button className="btn">Get Early Access</button>
            </SignInButton>
          </SignedOut>
          <button className="btn">See How It Works</button>
        </div>
      </section>

      {/* Early Access Card */}
      <section className="max-w-md mx-auto">
        <div className="glass p-10 text-center">
          <h3 className="text-4xl font-bold text-cyan-400 mb-6">Get Early Access</h3>
          <input
            type="email"
            placeholder="your@email.com"
            className="w-full px-6 py-5 bg-white/10 border border-white/30 rounded-2xl text-white placeholder-gray-500 mb-4"
          />
          <button className="w-full btn">Join Waitlist – First Month 50% Off</button>
          <p className="text-gray-500 text-sm mt-4">Limited spots. Matching starts January 2026.</p>
        </div>
      </section>

      {/* How It Works */}
      <section className="text-center">
        <h2 className="text-5xl font-bold text-cyan-400 mb-16">How GroundUp Works</h2>
        <div className="grid md:grid-cols-3 gap-12 max-w-5xl mx-auto">
          {[
            { n: "1", title: "Verify Privately", desc: "Zero-knowledge proofs confirm skills without revealing details." },
            { n: "2", title: "Match & 21-Day Chemistry", desc: "AI forms balanced teams; trial period ensures perfect fit." },
            { n: "3", title: "Incorporate & Execute", desc: "Legal templates + progress tracking for your state/industry." },
          ].map((step) => (
            <div key={step.n} className="glass p-10 text-center">
              <div className="text-7xl font-black text-cyan-400 mb-6">{step.n}</div>
              <h4 className="text-2xl font-bold mb-4">{step.title}</h4>
              <p className="text-gray-400 leading-relaxed">{step.desc}</p>
            </div>
          ))}
        </div>
      </section>
    </div>
  )
}
