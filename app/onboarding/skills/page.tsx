'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';

const SKILL_CATEGORIES = {
  technical: [
    'Frontend Development',
    'Backend Development',
    'Mobile Development',
    'DevOps',
    'Data Science',
    'Machine Learning',
    'Cybersecurity',
    'Database Management',
  ],
  business: [
    'Sales',
    'Marketing',
    'Product Management',
    'Business Development',
    'Finance',
    'Operations',
    'Strategy',
    'Customer Success',
  ],
  creative: [
    'UI/UX Design',
    'Graphic Design',
    'Content Writing',
    'Video Production',
    'Brand Strategy',
    'Social Media',
  ],
  operations: [
    'Project Management',
    'Supply Chain',
    'Quality Assurance',
    'Legal',
    'HR',
    'Administration',
  ],
};

export default function SkillsPage() {
  const router = useRouter();
  const [selectedSkills, setSelectedSkills] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');

  const toggleSkill = (skill: string) => {
    setSelectedSkills(prev =>
      prev.includes(skill)
        ? prev.filter(s => s !== skill)
        : [...prev, skill]
    );
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (selectedSkills.length === 0) {
      setError('Please select at least one skill');
      return;
    }

    setIsLoading(true);
    setError('');

    try {
      const response = await fetch('/api/onboarding/skills', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ skills: selectedSkills }),
      });

      if (!response.ok) {
        throw new Error('Failed to save skills');
      }

      router.push('/onboarding/preferences');
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
          <h1>What are your skills?</h1>
          <p>Select all that apply. You can add more later.</p>
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: '66%' }}></div>
          </div>
          <p className="progress-text">Step 2 of 3</p>
        </div>

        <form onSubmit={handleSubmit} className="onboarding-form">
          {Object.entries(SKILL_CATEGORIES).map(([category, skills]) => (
            <div key={category} className="skill-category">
              <h3>{category.charAt(0).toUpperCase() + category.slice(1)}</h3>
              <div className="skill-grid">
                {skills.map(skill => (
                  <button
                    key={skill}
                    type="button"
                    className={`skill-pill ${selectedSkills.includes(skill) ? 'selected' : ''}`}
                    onClick={() => toggleSkill(skill)}
                  >
                    {skill}
                  </button>
                ))}
              </div>
            </div>
          ))}

          <div className="selected-count">
            {selectedSkills.length} skill{selectedSkills.length !== 1 ? 's' : ''} selected
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
              {isLoading ? 'Saving...' : 'Continue →'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
