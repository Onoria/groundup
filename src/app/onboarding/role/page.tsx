'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'
import { ChevronRight } from 'lucide-react'

const roles = [
  { id: 'visionary_tech', name: 'Visionary / CEO (Tech)', track: 'tech' },
  { id: 'technical_lead', name: 'Technical Lead / CTO', track: 'tech' },
  { id: 'growth_marketing', name: 'Growth & Marketing Lead', track: 'tech' },
  { id: 'owner_operator', name: 'Owner-Operator / Visionary', track: 'bluecollar' },
  { id: 'master_tradesman', name: 'Master Tradesman', track: 'bluecollar' },
  { id: 'sales_closer', name: 'Sales & Rainmaker', track: 'bluecollar' },
]

export default function RoleSelection() {
  const [selected, setSelected] = useState<string>('')
  const router = useRouter()
  const supabase = createClient()

  const handleSubmit = async () => {
    if (!selected) return
    const { error } = await supabase
      .from('user_roles')
      .upsert({ role_id: roles.find(r => r.id === selected)?.id, is_primary: true })
    if (!error) router.push('/onboarding/questions')
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-slate-950 to-slate-900 text-white p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-5xl font-black text-center mb-4">Choose Your Primary Role</h1>
        <p className="text-xl text-center text-slate-300 mb-12">You can only pick one — this is your core strength.</p>

        <div className="grid md:grid-cols-2 gap-6">
          {roles.map(role => (
            <button
              key={role.id}
              onClick={() => setSelected(role.id)}
              className={`p-8 rounded-2xl border-2 transition-all text-left
                ${selected === role.id 
                  ? 'border-emerald-500 bg-emerald-500/10 shadow-2xl shadow-emerald-500/20' 
                  : 'border-slate-700 hover:border-slate-500 bg-slate-800/50'}`}
            >
              <h3 className="text-2xl font-bold mb-2">{role.name}</h3>
              <p className="text-slate-400">Track: {role.track === 'tech' ? 'Tech Startup' : 'Blue-Collar Empire'}</p>
              {selected === role.id && <ChevronRight className="w-8 h-8 ml-auto mt-4 text-emerald-500" />}
            </button>
          ))}
        </div>

        <div className="text-center mt-12">
          <button
            onClick={handleSubmit}
            disabled={!selected}
            className="bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 px-12 py-6 text-2xl rounded-xl font-bold transition shadow-2xl"
          >
            Continue to Questionnaire →
          </button>
        </div>
      </div>
    </div>
  )
}