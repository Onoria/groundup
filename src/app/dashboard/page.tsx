import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

export default async function DashboardPage() {
  const supabase = createClient();
  const { data: { session } } = await supabase.auth.getSession();

  if (!session) {
    redirect('/signin');
  }

  // Future: Fetch user sub status, LinkedIn data, available matches via Supabase queries
  // e.g., const { data: user } = await supabase.from('users').select('*').eq('id', session.user.id).single();

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="text-center">
          <h1 className="text-4xl font-extrabold text-gray-900">
            Welcome back, {session.user.email}!
          </h1>
          <p className="mt-4 text-xl text-gray-600">
            Ready to assemble your startup dungeon? Match with co-founders, track progress, and launch.
          </p>
        </div>
        <div className="mt-12 grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-3">
          {/* Teaser Cards: Expand with real data */}
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-6">
              <h3 className="text-lg font-medium text-gray-900">Find Matches</h3>
              <p className="mt-2 text-sm text-gray-500">Connect with one of each role in your industry/state.</p>
              <button className="mt-4 bg-blue-600 text-white px-4 py-2 rounded">Search Teams</button>
            </div>
          </div>
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-6">
              <h3 className="text-lg font-medium text-gray-900">Link LinkedIn</h3>
              <p className="mt-2 text-sm text-gray-500">Verify experience for better matches.</p>
              <button className="mt-4 bg-green-600 text-white px-4 py-2 rounded">Connect Now</button>
            </div>
          </div>
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-6">
              <h3 className="text-lg font-medium text-gray-900">Track Progress</h3>
              <p className="mt-2 text-sm text-gray-500">Monitor your team's journey to launch.</p>
              <button className="mt-4 bg-purple-600 text-white px-4 py-2 rounded">View Milestones</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}