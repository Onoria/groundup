import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/nextjs'
import Link from 'next/link'

export default function HomePage() {
  return (
    <div className="flex flex-col items-center gap-24">
      {/* HERO */}
      <section className="w-full pt-4">
        <div className="mx-auto flex max-w-3xl flex-col items-center text-center gap-8">
          <div className="space-y-4">
            <h1 className="text-4xl sm:text-5xl md:text-6xl font-semibold tracking-tight bg-gradient-to-b from-emerald-300 to-cyan-400 bg-clip-text text-transparent">
              GroundUp
            </h1>
            <div className="space-y-1 text-sm sm:text-base text-slate-200">
              <p>Prove your skills privately with zero-knowledge proofs.</p>
              <p>Form balanced founding teams for tech startups or blue-collar empires.</p>
              <p>Incorporate in week one. Hire verified American labor. Build real companies from the ground up.</p>
            </div>
          </div>

          <div className="flex flex-wrap items-center justify-center gap-4">
            <SignedIn>
              <Link href="/match">
                <button className="rounded-full bg-emerald-500 px-7 py-3 text-sm font-semibold text-slate-950 shadow-lg shadow-emerald-500/40 transition hover:bg-emerald-400 hover:-translate-y-0.5">
                  Join the Waitlist – $49/mo
                </button>
              </Link>
            </SignedIn>
            <SignedOut>
              <SignInButton mode="modal">
                <button className="rounded-full bg-emerald-500 px-7 py-3 text-sm font-semibold text-slate-950 shadow-lg shadow-emerald-500/40 transition hover:bg-emerald-400 hover:-translate-y-0.5">
                  Get Early Access
                </button>
              </SignInButton>
            </SignedOut>
            <button className="rounded-full border border-emerald-400/70 px-7 py-3 text-sm font-semibold text-emerald-200 shadow-md shadow-emerald-500/25 transition hover:bg-emerald-500/10 hover:-translate-y-0.5">
              See How It Works
            </button>
          </div>
        </div>
      </section>

      {/* EARLY ACCESS CARD */}
      <section className="w-full flex justify-center">
        <div className="w-full max-w-lg rounded-3xl border border-cyan-300/40 bg-slate-900/70 px-8 py-7 shadow-2xl shadow-cyan-500/25 backdrop-blur-xl">
          <h2 className="text-lg font-semibold text-slate-50 mb-4">Get Early Access</h2>
          <form className="space-y-4">
            <input
              type="email"
              placeholder="your@email.com"
              className="w-full rounded-full border border-slate-600 bg-slate-950/60 px-4 py-2.5 text-sm text-slate-100 placeholder:text-slate-500 focus:border-emerald-400 focus:outline-none focus:ring-1 focus:ring-emerald-400"
            />
            <button className="w-full rounded-full bg-emerald-500 px-6 py-3 text-sm font-semibold text-slate-950 shadow-lg shadow-emerald-500/40 transition hover:bg-emerald-400 hover:-translate-y-0.5">
              Join Waitlist – First Month 50% Off
            </button>
          </form>
          <p className="mt-3 text-[11px] text-slate-400">
            Limited spots. Matching starts January 2026.
          </p>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="w-full pb-4">
        <div className="mx-auto flex max-w-4xl flex-col gap-6 text-slate-100">
          <h2 className="text-center text-2xl font-semibold tracking-tight">
            How GroundUp Works
          </h2>

          <div className="grid gap-4 sm:grid-cols-3">
            {[
              { n: "1", title: "Verify Privately", desc: "Zero-knowledge proofs confirm skills without revealing details." },
              { n: "2", title: "Match & 21-Day Chemistry", desc: "AI forms balanced teams; trial period ensures perfect fit." },
              { n: "3", title: "Incorporate & Execute", desc: "Legal templates + progress tracking for your state/industry." },
            ].map((step) => (
              <article key={step.n} className="rounded-2xl border border-slate-700/80 bg-slate-900/80 p-4 shadow-xl shadow-slate-950/70">
                <div className="mb-3 flex items-center justify-between text-xs text-slate-400">
                  <span className="inline-flex h-6 w-6 items-center justify-center rounded-full bg-emerald-500/15 text-[11px] font-semibold text-emerald-300">
                    {step.n}
                  </span>
                  <span>{step.n === "1" ? "Verify" : step.n === "2" ? "Match" : "Execute"}</span>
                </div>
                <h3 className="text-sm font-semibold text-slate-50">{step.title}</h3>
                <p className="mt-1 text-xs text-slate-300">{step.desc}</p>
              </article>
            ))}
          </div>
        </div>
      </section>
    </div>
  )
}
