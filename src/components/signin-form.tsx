'use client'

import { signInAction } from '@/app/auth/actions'

export function SignInForm() {
  return (
    <form action={signInAction} className="mt-8 space-y-6">
      <div className="space-y-4">
        <input name="email" type="email" required placeholder="Email" className="w-full px-3 py-2 border rounded-md" />
        <input name="password" type="password" required placeholder="Password" className="w-full px-3 py-2 border rounded-md" />
      </div>
      <button
        type="submit"
        className="w-full py-2 px-4 bg-blue-600 text-white rounded-md hover:bg-blue-700"
      >
        Sign in
      </button>
    </form>
  )
}
