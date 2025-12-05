import Link from 'next/link'

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-white">
      <div className="container mx-auto px-6 pt-24 pb-32 text-center">
        <h1 className="text-6xl md:text-8xl font-black bg-clip-text text-transparent bg-gradient-to-r from-emerald-400 to-cyan-400">
          GroundUp
        </h1>
        <p className="mt-8 text-xl md:text-3xl text-slate-300 max-w-4xl mx-auto leading-relaxed">
          Prove your skills privately with zero-knowledge proofs.<br />
          Form balanced founding teams for tech startups or blue-collar empires.<br />
          Incorporate in week one. Hire verified American labor. Build real companies from the ground up.
        </p>
        <div className="mt-16">
          <Link
            href="/onboarding/role"
            className="bg-emerald-600 hover:bg-emerald-500 px-16 py-6 text-2xl rounded-xl font-bold transition shadow-2xl"
          >
            Start Matching – $49/mo
          </Link>
        </div>
      </div>
    </main>
  )
}