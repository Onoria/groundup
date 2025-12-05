import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
import { SignInForm } from '@/components/signin-form'; // Create this next

export default function SignInPage({
  searchParams,
}: {
  searchParams: { error?: string };
}) {
  const error = searchParams.error;

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Sign in to GroundUp
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Build your startup team—find your co-founders today.
          </p>
        </div>
        {error && (
          <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
            {decodeURIComponent(error)}
          </div>
        )}
        <SignInForm />
        <div className="text-center">
          <a href="/signup" className="text-blue-600 hover:text-blue-500">
            Don't have an account? Sign up
          </a>
        </div>
      </div>
    </div>
  );
}

// Server action: Handles form submit (call from <form action={signInAction}>)
export async function signInAction(formData: FormData) {
  'use server';
  const supabase = createClient();
  const email = formData.get('email') as string;
  const password = formData.get('password') as string;

  const { error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error) {
    redirect(`/signin?error=${encodeURIComponent(error.message)}`);
  }

  // Success: Redirect to dashboard (future: check sub status, prompt LinkedIn link)
  redirect('/dashboard');
}