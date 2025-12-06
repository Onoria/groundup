'use client'

import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useUser } from '@clerk/nextjs'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

const schema = z.object({
  role: z.enum(['Founder', 'Developer', 'Designer', 'Marketer']),
  experience: z.enum(['Junior', 'Mid', 'Senior']),
  state: z.string().min(2),
  industry: z.string().min(3),
})

type FormData = z.infer<typeof schema>

export default function Onboard() {
  const { user, isLoaded } = useUser()
  const router = useRouter()
  const [step, setStep] = useState(1)
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    resolver: zodResolver(schema),
  })

  if (!isLoaded) return <div className="flex min-h-screen items-center justify-center">Loading...</div>

  const onSubmit = async (data: FormData) => {
    if (user) {
      try {
        await user.update({
          publicMetadata: { ...user.publicMetadata, ...data }
        })
      } catch (error) {
        console.error('Metadata update failed:', error)
        // Still redirect on error for MVP
      }
    }
    router.push('/dashboard')
  }

  const roles = ['Founder', 'Developer', 'Designer', 'Marketer']
  const experiences = ['Junior', 'Mid', 'Senior']
  const states = ['CA', 'NY', 'TX', 'FL'] // Add more
  const industries = ['Fintech', 'Health', 'SaaS', 'Ecommerce']

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-gray-900 to-black text-white px-4">
      <div className="max-w-md w-full space-y-8 p-8 bg-white/10 rounded-xl">
        <h1 className="text-3xl font-bold text-center">Assemble Your Profile</h1>
        <p className="text-gray-300 text-center">Step {step}/4: Tell us about you for perfect matches.</p>
        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
          {step === 1 && (
            <div>
              <label className="block text-sm font-medium mb-2">Role</label>
              <select {...register('role')} className="w-full p-2 rounded bg-gray-800 text-white">
                {roles.map(r => <option key={r} value={r}>{r}</option>)}
              </select>
              {errors.role && <p className="text-red-500 text-sm">{errors.role.message}</p>}
              <button type="button" onClick={() => setStep(2)} className="mt-4 w-full bg-blue-600 hover:bg-blue-700 rounded p-2 transition">Next</button>
            </div>
          )}
          {step === 2 && (
            <div>
              <label className="block text-sm font-medium mb-2">Experience Level</label>
              <select {...register('experience')} className="w-full p-2 rounded bg-gray-800 text-white">
                {experiences.map(e => <option key={e} value={e}>{e}</option>)}
              </select>
              {errors.experience && <p className="text-red-500 text-sm">{errors.experience.message}</p>}
              <button type="button" onClick={() => setStep(3)} className="mt-4 w-full bg-blue-600 hover:bg-blue-700 rounded p-2 transition">Next</button>
            </div>
          )}
          {step === 3 && (
            <div>
              <label className="block text-sm font-medium mb-2">State (for regs)</label>
              <select {...register('state')} className="w-full p-2 rounded bg-gray-800 text-white">
                {states.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
              {errors.state && <p className="text-red-500 text-sm">{errors.state.message}</p>}
              <button type="button" onClick={() => setStep(4)} className="mt-4 w-full bg-blue-600 hover:bg-blue-700 rounded p-2 transition">Next</button>
            </div>
          )}
          {step === 4 && (
            <div>
              <label className="block text-sm font-medium mb-2">Industry Niche</label>
              <select {...register('industry')} className="w-full p-2 rounded bg-gray-800 text-white">
                {industries.map(i => <option key={i} value={i}>{i}</option>)}
              </select>
              {errors.industry && <p className="text-red-500 text-sm">{errors.industry.message}</p>}
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
