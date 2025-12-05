'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'

const roles = [
  { id: 'visionary_tech', name: 'Visionary / CEO', track: 'tech' },
  { id: 'technical_lead', name: 'Technical Lead / CTO', track: 'tech' },
  { id: 'growth_marketing', name: 'Growth & Marketing Lead', track: 'tech' },
  { id: 'product_designer', name: 'Product Designer', track: 'tech' },
  { id: 'ops_finance', name: 'Operations & Finance Lead', track: 'tech' },
  { id: 'owner_operator', name: 'Owner-Operator / Visionary', track: 'bluecollar' },
  { id: 'master_tradesman', name: 'Master Tradesman', track: 'bluecollar' },
  { id: 'sales_closer', name: 'Sales & Business Development', track: 'bluecollar' },
  { id: 'ops_fleet', name: 'Operations & Fleet Manager', track: 'bluecollar' },
  { id: 'finance_admin', name: 'Finance & Administration', track: 'bluecollar' },
]

export default function RoleSelection() {
  const [selected, setSelected] = useState('')
  const router = useRouter()
  const supabase = createClient()

  const handleContinue = async () => {
    if (!selected) return
    await supabase.from('user_roles').upsert({ role_id: selected, is_primary: true })
    router.push('/onboarding/questions')
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-white p-8">
      <div className="max-w-5xl mx-auto text-center">
        <h1 className="text-5xl font-black mb-6">Choose Your Primary Role</h1>
        <div className="grid md:grid-cols-3 gap-8">
          {roles.map(role => (
            <button
              key={role.id}
              onClick={() => setSelected(role.id)}
              className={`p-10 rounded-2xl border-4 transition-all
                ${selected === role.id
                  ? 'border-emerald-500 bg-emerald-500/10 shadow-2xl'
                  : 'border-slate-700 hover:border-slate-500 bg-slate-800/50'}`}
            >
              <h3 className="text-2xl font-bold mb-3">{role.name}</h3>
              <p className="text-emerald-400 text-sm uppercase tracking-wider">
                {role.track === 'tech' ? 'Tech Startup' : 'Blue-Collar Empire'}
              </p>
            </button>
          ))}
        </div>
        <button
          onClick={handleContinue}
          disabled={!selected}
          className="mt-16 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 px-16 py-6 text-2xl rounded-xl font-bold transition shadow-2xl"
        >
          Continue to Questionnaire →
        </button>
      </div>
    </div>
  )
}