'use client'

import { useState } from 'react'
import { ChevronRight } from 'lucide-react'

const roles = [
  { id: 'visionary_tech', name: 'Visionary / CEO', track: 'Tech Startup' },
  { id: 'technical_lead', name: 'Technical Lead / CTO', track: 'Tech Startup' },
  { id: 'growth_marketing', name: 'Growth & Marketing Lead', track: 'Tech Startup' },
  { id: 'product_designer', name: 'Product Designer', track: 'Tech Startup' },
  { id: 'ops_finance', name: 'Operations & Finance Lead', track: 'Tech Startup' },
  { id: 'owner_operator', name: 'Owner-Operator / Visionary', track: 'Blue-Collar Empire' },
  { id: 'master_tradesman', name: 'Master Tradesman', track: 'Blue-Collar Empire' },
  { id: 'sales_closer', name: 'Sales & Business Development', track: 'Blue-Collar Empire' },
  { id: 'ops_fleet', name: 'Operations & Fleet Manager', track: 'Blue-Collar Empire' },
  { id: 'finance_admin', name: 'Finance & Administration', track: 'Blue-Collar Empire' },
]

export default function RoleSelection() {
  const [selected, setSelected] = useState('')

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-white p-8">
      <div className="max-w-6xl mx-auto">
        <h1 className="text-5xl font-black text-center mb-4">Choose Your Primary Role</h1>
        <p className="text-xl text-slate-400 text-center mb-12 max-w-3xl mx-auto">
          You can only pick <strong>one</strong>. This is your core strength — no unicorns.
        </p>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-8">
          {roles.map((role) => (
            <button
              key={role.id}
              onClick={() => setSelected(role.id)}
              className={`p-8 rounded-2xl border-4 transition-all text-left h-full flex flex-col justify-between
                ${selected === role.id
                  ? 'border-emerald-500 bg-emerald-500/10 shadow-2xl shadow-emerald-500/30'
                  : 'border-slate-700 hover:border-slate-500 bg-slate-800/50'}`}
            >
              <div>
                <h3 className="text-2xl font-bold mb-2">{role.name}</h3>
                <p className="text-emerald-400 text-sm uppercase tracking-wider">{role.track}</p>
              </div>
              {selected === role.id && (
                <ChevronRight className="w-12 h-12 ml-auto mt-6 text-emerald-500" />
              )}
            </button>
          ))}
        </div>

        <div className="text-center mt-16">
          <button
            disabled={!selected}
            className="bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed px-20 py-6 text-3xl rounded-xl font-bold transition shadow-2xl"
          >
            Continue to Questionnaire →
          </button>
        </div>
      </div>
    </div>
  )
}