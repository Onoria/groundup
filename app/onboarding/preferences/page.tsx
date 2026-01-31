'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

const INDUSTRIES = [
  'Software & Technology',
  'Healthcare',
  'Finance & Fintech',
  'E-commerce & Retail',
  'Education',
  'Manufacturing',
  'Real Estate',
  'Energy & Utilities',
  'Transportation & Logistics',
  'Media & Entertainment',
  'Food & Beverage',
  'Construction',
  'Agriculture',
  'Professional Services',
  'Other',
];

const ROLES_LOOKING_FOR = [
  'Technical Co-founder (CTO)',
  'Business Co-founder (CEO)',
  'Product Lead',
  'Marketing Lead',
  'Sales Lead',
  'Finance Lead (CFO)',
  'Operations Lead',
  'Design Lead',
];

export default function PreferencesPage() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    industries: [] as string[],
    rolesLookingFor: [] as string[],
    availability: 'full-time',
  });
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  const toggleIndustry = (industry: string) => {
    setFormData(prev => ({
      ...prev,
      industries: prev.industries.includes(industry)
        ? prev.industries.filter(i => i !== industry)
        : [...prev.industries, industry],
    }));
  };

  const toggleRole = (role: string) => {
    setFormData(prev => ({
      ...prev,
      rolesLookingFor: prev.rolesLookingFor.includes(role)
        ? prev.rolesLookingFor.filter(r => r !== role)
        : [...prev.rolesLookingFor, role],
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (formData.industries.length === 0) {
      setError('Please select at least one industry');
      return;
    }

    if (formData.rolesLookingFor.length === 0) {
      setError('Please select at least one role you\'re looking for');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      const response = await fetch('/api/onboarding/preferences', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });

      if (!response.ok) {
        throw new Error('Failed to save preferences');
      }

      // Complete! Redirect to dashboard
      router.push('/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="onboarding-container">
      <div className="onboarding-card wide">
        <div className="onboarding-header">
          <h1>What are you looking for?</h1>
          <p>Help us match you with the right co-founders</p>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: '100%' }}></div>
          </div>
          <p className="progress-text">Step 3 of 3</p>
        </div>

        <form onSubmit={handleSubmit} className="onboarding-form">
          <div className="form-section">
            <h3>Industries of Interest</h3>
            <p className="form-hint">Select all industries you're interested in building in</p>
            <div className="skill-grid">
              {INDUSTRIES.map(industry => (
                <button
                  key={industry}
                  type="button"
                  className={`skill-pill ${formData.industries.includes(industry) ? 'selected' : ''}`}
                  onClick={() => toggleIndustry(industry)}
                >
                  {industry}
                </button>
              ))}
            </div>
          </div>

          <div className="form-section">
            <h3>Roles You're Looking For</h3>
            <p className="form-hint">What roles do you need on your founding team?</p>
            <div className="skill-grid">
              {ROLES_LOOKING_FOR.map(role => (
                <button
                  key={role}
                  type="button"
                  className={`skill-pill ${formData.rolesLookingFor.includes(role) ? 'selected' : ''}`}
                  onClick={() => toggleRole(role)}
                >
                  {role}
                </button>
              ))}
            </div>
          </div>

          <div className="form-section">
            <h3>Your Availability</h3>
            <div className="radio-group">
              <label className="radio-label">
                <input
                  type="radio"
                  name="availability"
                  value="full-time"
                  checked={formData.availability === 'full-time'}
                  onChange={(e) => setFormData({ ...formData, availability: e.target.value })}
                />
                <span>Full-time (40+ hours/week)</span>
              </label>
              <label className="radio-label">
                <input
                  type="radio"
                  name="availability"
                  value="part-time"
                  checked={formData.availability === 'part-time'}
                  onChange={(e) => setFormData({ ...formData, availability: e.target.value })}
                />
                <span>Part-time (20-40 hours/week)</span>
              </label>
              <label className="radio-label">
                <input
                  type="radio"
                  name="availability"
                  value="nights-weekends"
                  checked={formData.availability === 'nights-weekends'}
                  onChange={(e) => setFormData({ ...formData, availability: e.target.value })}
                />
                <span>Nights & Weekends</span>
              </label>
            </div>
          </div>

          {error && <div className="error-message">{error}</div>}

          <div className="form-actions">
            <button
              type="button"
              className="btn btn-outline"
              onClick={() => router.back()}
            >
              ← Back
            </button>
            <button type="submit" className="btn btn-primary" disabled={isLoading}>
              {isLoading ? 'Saving...' : 'Complete Setup ✓'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
