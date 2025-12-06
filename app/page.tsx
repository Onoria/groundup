import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div style={{ minHeight: '100vh', background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)' }}>
      <header style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', backdropFilter: 'blur(12px)' }}>
        <div className="max-w-7xl mx-auto px-6 py-6 flex justify-between items-center">
          <h1 className="heading">GroundUp</h1>
          <div className="flex items-center gap-8">
            <SignedOut>
              <SignInButton mode="modal">
                <button style={{ color: '#94a3b8' }} className="hover:text-white transition">Sign in</button>
              </SignInButton>
            </SignedOut>
            <SignedIn>
              <UserButton afterSignOutUrl="/" />
            </SignedIn>
          </div>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-6 pt-32 text-center">
        <p style={{ fontSize: '1.875rem', color: '#cbd5e1', marginBottom: '1.5rem' }}>
          Prove your skills privately with zero-knowledge proofs.
        </p>
        <p style={{ fontSize: '1.5rem', color: '#94a3b8', marginBottom: '4rem', maxWidth: '64rem' }} className="mx-auto">
          Form balanced founding teams for tech startups or blue-collar empires.<br />
          Incorporate in week one. Hire verified American labor. Build real companies from the ground up.
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem', alignItems: 'center', marginBottom: '5rem' }} className="sm:flex-row justify-center">
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
          <button className="btn" style={{ opacity: 0.8 }}>See How It Works</button>
        </div>

        <div className="glass max-w-lg mx-auto mb-20">
          <h3 style={{ fontSize: '2rem', fontWeight: '700', color: '#67e8f9', marginBottom: '1.5rem' }}>
            Get Early Access
          </h3>
          <input
            type="email"
            placeholder="your@email.com"
            style={{ width: '100%', padding: '1rem 1.5rem', background: 'rgba(255,255,255,0.1)', border: '1px solid rgba(255,255,255,0.2)', borderRadius: '12px', color: 'white', marginBottom: '1rem' }}
          />
          <button className="btn" style={{ width: '100%' }}>Join Waitlist – First Month 50% Off</button>
          <p style={{ fontSize: '0.875rem', color: '#64748b', marginTop: '1rem' }}>
            Limited spots. Matching starts January 2026.
          </p>
        </div>

        <div style={{ display: 'grid', gap: '2.5rem', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))' }}>
          {[
            { n: "1", title: "Verify Privately", desc: "Zero-knowledge proofs confirm skills without revealing details." },
            { n: "2", title: "Match & 21-Day Chemistry", desc: "AI forms balanced teams; trial period ensures perfect fit." },
            { n: "3", title: "Incorporate & Execute", desc: "Legal templates + progress tracking for your state/industry." },
          ].map(s => (
            <div key={s.n} className="glass text-center">
              <div style={{ fontSize: '4rem', fontWeight: 'bold', color: '#67e8f9', marginBottom: '1rem' }}>{s.n}</div>
              <h4 style={{ fontSize: '1.5rem', fontWeight: '600', marginBottom: '1rem' }}>{s.title}</h4>
              <p style={{ color: '#94a3b8' }}>{s.desc}</p>
            </div>
          ))}
        </div>
      </main>
    </div>
  )
}
