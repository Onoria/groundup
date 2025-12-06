import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="landing">
      {/* HERO */}
      <section className="hero">
        <h1 className="hero-title">GroundUp</h1>
        <div className="hero-subtitle">
          <p>Prove your skills privately with zero-knowledge proofs.</p>
          <p>Form balanced founding teams for tech startups or blue-collar empires.</p>
          <p>Incorporate in week one. Hire verified American labor. Build real companies from the ground up.</p>
        </div>

        <div className="hero-actions">
          <SignedIn>
            <Link href="/match">
              <button className="btn btn-primary">Join the Waitlist – $49/mo</button>
            </Link>
          </SignedIn>
          <SignedOut>
            <SignInButton mode="modal">
              <button className="btn btn-primary">Get Early Access</button>
            </SignInButton>
          </SignedOut>
          <button className="btn btn-outline">See How It Works</button>
        </div>
      </section>

      {/* EARLY ACCESS */}
      <section className="early-access-section">
        <div className="early-access-card">
          <h2 className="early-access-title">Get Early Access</h2>
          <form>
            <div className="early-access-input-row">
              <input type="email" placeholder="your@email.com" className="early-access-input" />
              <button className="btn btn-primary">Join Waitlist – First Month 50% Off</button>
            </div>
          </form>
          <p className="early-access-footer">
            Limited spots. Matching starts January 2026.
          </p>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="how-section">
        <h2 className="how-title">How GroundUp Works</h2>
        <div className="how-steps">
          <article className="step-card">
            <div className="step-number">1</div>
            <h3 className="step-title">Verify Privately</h3>
            <p className="step-body">Zero-knowledge proofs confirm skills without revealing details.</p>
          </article>
          <article className="step-card">
            <div className="step-number">2</div>
            <h3 className="step-title">Match & 21-Day Chemistry</h3>
            <p className="step-body">AI forms balanced teams; a trial period ensures perfect fit before equity.</p>
          </article>
          <article className="step-card">
            <div className="step-number">3</div>
            <h3 className="step-title">Incorporate & Execute</h3>
            <p className="step-body">Legal templates and progress tracking for your state and industry.</p>
          </article>
        </div>
      </section>
    </div>
  )
}
