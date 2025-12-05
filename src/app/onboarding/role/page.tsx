'use client'

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
  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-white p-8">
      <div className="max-w-6xl mx-auto text-center">
        <h1 className="text-5xl font-black mb-12">Choose Your Primary Role</h1>
        <div className="grid md:grid-cols-3 lg:grid-cols-5 gap-8">
          {roles.map(role => (
            <div key={role.id} className="p-10 rounded-2xl border-4 border-slate-700 bg-slate-800/50 hover:border-slate-500 transition">
              <h3 className="text-2xl font-bold mb-3">{role.name}</h3>
              <p className="text-emerald-400 text-sm uppercase tracking-wider">{role.track}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}