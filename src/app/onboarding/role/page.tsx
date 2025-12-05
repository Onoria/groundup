'use client'

const roles = [
  { name: 'Visionary / CEO', track: 'Tech Startup' },
  { name: 'Technical Lead / CTO', track: 'Tech Startup' },
  { name: 'Growth & Marketing Lead', track: 'Tech Startup' },
  { name: 'Product Designer', track: 'Tech Startup' },
  { name: 'Operations & Finance Lead', track: 'Tech Startup' },
  { name: 'Owner-Operator / Visionary', track: 'Blue-Collar Empire' },
  { name: 'Master Tradesman', track: 'Blue-Collar Empire' },
  { name: 'Sales & Business Development', track: 'Blue-Collar Empire' },
  { name: 'Operations & Fleet Manager', track: 'Blue-Collar Empire' },
  { name: 'Finance & Administration', track: 'Blue-Collar Empire' },
]

export default function RoleSelection() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-white p-12">
      <div className="max-w-6xl mx-auto text-center">
        <h1 className="text-5xl font-black mb-16">Choose Your Primary Role</h1>
        <div className="grid md:grid-cols-3 gap-10">
          {roles.map((role, i) => (
            <div
              key={i}
              className="bg-slate-800/50 border-4 border-slate-700 rounded-2xl p-12 hover:border-emerald-500 transition cursor-pointer"
            >
              <h3 className="text-3xl font-bold mb-4">{role.name}</h3>
              <p className="text-emerald-400 text-lg">{role.track}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}