'use client'

import { useState } from 'react'
import { useFormState } from 'react-dom'
import { updateUserMetadata } from '../actions'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function Onboard() {
  const [step, setStep] = useState(1)
  const [state, formAction] = useFormState(updateUserMetadata, { success: false })
  const router = useRouter()

  if (state.success) {
    router.push('/dashboard')
    return null
  }

  const roles = ['Founder', 'Developer', 'Designer', 'Marketer']
  const experiences = ['Junior', 'Mid', 'Senior']
  const states = ['CA', 'NY', 'TX', 'FL']
  const industries = ['Fintech', 'Health', 'SaaS', 'Ecommerce']

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-gray-900 to-black text-white px-4">
      <div className="max-w-md w-full space-y-8 p-8 bg-white/10 rounded-xl">
        <h1 className="text-3xl font-bold text-center">Assemble Your Profile</h1>
        <p className="text-gray-300 text-center">Step {step}/4: Tell us about you for perfect matches.</p>
        <form action={formAction} className="space-y-4">
          {step === 1 && (
            <div>
              <label className="block text-sm font-medium mb-2">Role</label>
              <select name="role" className="w-full p-2 rounded bg-gray-800 text-white">
                {roles.map(r => <option key={r} value={r}>{r}</option>)}
              </select>
              <button type="button" onClick={() => setStep(2)} className="mt-4 w-full bg-blue-600 hover:bg-blue-700 rounded p-2 transition">Next</button>
            </div>
          )}
          {step === 2 && (
            <div>
              <label className="block text-sm font-medium mb-2">Experience Level</label>
              <select name="experience" className="w-full p-2 rounded bg-gray-800 text-white">
                {experiences.map(e => <option key={e} value={e}>{e}</option>)}
              </select>
              <button type="button" onClick={() => setStep(3)} className="mt-4 w-full bg-blue-600 hover:bg-blue-700 rounded p-2 transition">Next</button>
            </div>
          )}
          {step === 3 && (
            <div>
              <label className="block text-sm font-medium mb-2">State (for regs)</label>
              <select name="state" className="w-full p-2 rounded bg-gray-800 text-white">
                {states.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
              <button type="button" onClick={() => setStep(4)} className="mt-4 w-full bg-blue-600 hover:bg-blue-700 rounded p-2 transition">Next</button>
            </div>
          )}
          {step === 4 && (
            <div>
              <label className="block text-sm font-medium mb-2">Industry Niche</label>
              <select name="industry" className="w-full p-2 rounded bg-gray-800 text-white">
                {industries.map(i => <option key={i} value={i}>{i}</option>)}
              </select>
              <button type="submit" className="mt-4 w-full bg-green-600 hover:bg-green-700 rounded p-2 transition">Save & Find Party</button>
              <Link href="/dashboard" className="block text-center text-gray-400 mt-2 hover:text-white transition">Skip for now</Link>
            </div>
          )}
        </form>
        <button className="w-full text-sm text-gray-400 hover:text-white transition">Connect LinkedIn (Coming Soon)</button>
      </div>
    </div>
  )
}
