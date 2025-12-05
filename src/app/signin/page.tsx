import { SignInForm } from '@/components/signin-form'
import { signInAction } from '@/app/auth/actions'

export default function SignInPage({
  searchParams,
}: {
  searchParams: { error?: string }
}) {
  const error = searchParams.error

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Sign in to GroundUp
          </h2>
        </div>
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
            {decodeURIComponent(error)}
          </div>
        )}
        <SignInForm />
      </div>
    </div>
  )
}
