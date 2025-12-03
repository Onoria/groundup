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
        <div className="mt-16 flex flex-col sm:flex-row gap-6 justify-center items-center">
          <a href="/signup" className="bg-emerald-600 hover:bg-emerald-500 px-12 py-6 text-2xl rounded-xl font-bold transition shadow-2xl">
            Start Matching – $49/mo
          </a>
          <a href="#how" className="border-2 border-cyan-400 text-cyan-400 hover:bg-cyan-400 hover:text-slate-900 px-12 py-6 text-2xl rounded-xl font-bold transition">
            How It Works
          </a>
        </div>
      </div>

      <section id="waitlist" className="max-w-2xl mx-auto mt-32 bg-slate-800/50 backdrop-blur rounded-2xl p-12 border border-slate-700">
        <h2 className="text-4xl font-bold mb-8 text-center">Get Early Access</h2>
        <form className="space-y-6">
          <input type="email" placeholder="your@email.com" className="w-full px-6 py-4 rounded-lg bg-slate-900 border border-slate-700 focus:border-emerald-500 outline-none text-lg" required />
          <button type="submit" className="w-full bg-emerald-600 hover:bg-emerald-500 py-4 rounded-lg font-bold text-xl transition">
            Join Waitlist – First Month 50% Off
          </button>
        </form>
        <p className="mt-6 text-slate-400 text-sm text-center">
          Limited spots. Matching starts January 2026.
        </p>
      </section>

      <section id="how" className="mt-32 text-center px-6">
        <h2 className="text-5xl font-bold mb-16">How GroundUp Works</h2>
        <div className="grid md:grid-cols-3 gap-12 max-w-5xl mx-auto">
          <div className="bg-slate-800/50 backdrop-blur p-8 rounded-xl border border-slate-700">
            <div className="text-emerald-500 text-6xl mb-4">1</div>
            <h3 className="text-2xl font-bold mb-4">Verify Privately</h3>
            <p className="text-slate-300">Hybrid ZKP + LinkedIn. Prove experience without revealing details.</p>
          </div>
          <div className="bg-slate-800/50 backdrop-blur p-8 rounded-xl border border-slate-700">
            <div className="text-emerald-500 text-6xl mb-4">2</div>
            <h3 className="text-2xl font-bold mb-4">Match & 21-Day Chemistry</h3>
            <p className="text-slate-300">Balanced teams. Brainstorm, video calls, anonymous feedback.</p>
          </div>
          <div className="bg-slate-800/50 backdrop-blur p-8 rounded-xl border border-slate-700">
            <div className="text-emerald-500 text-6xl mb-4">3</div>
            <h3 className="text-2xl font-bold mb-4">Incorporate & Execute</h3>
            <p className="text-slate-300">Week-one LLC. WorkerHub directory. Milestones. Graduate as a real company.</p>
          </div>
        </div>
      </section>
    </main>
  )
}/* Production deploy fix */
