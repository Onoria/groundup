"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type Track = "startup" | "trades";

const TRACKS: { id: Track; icon: string; label: string; tagline: string; description: string; color: string }[] = [
  {
    id: "startup",
    icon: "🚀",
    label: "Startup",
    tagline: "Find your cofounder",
    description: "Tech startups, SaaS, digital products, and venture-backed companies. Match with engineers, designers, and business minds.",
    color: "#22d3ee",
  },
  {
    id: "trades",
    icon: "🔨",
    label: "Trades & Services",
    tagline: "Find your business partner",
    description: "Commercial contractors, service companies, and skilled trades. Match with licensed professionals and experienced operators.",
    color: "#fbbf24",
  },
];

export default function SelectTrackPage() {
  const router = useRouter();
  const [selected, setSelected] = useState<Track | null>(null);
  const [loading, setLoading] = useState(false);

  async function confirm() {
    if (!selected) return;
    setLoading(true);

    try {
      const res = await fetch("/api/track", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ track: selected }),
      });
      const data = await res.json();
      if (!data.error) {
        router.push("/onboarding");
      }
    } catch {}
    setLoading(false);
  }

  return (
    <div className="track-container">
      <div className="track-card">
        <h1 className="track-title">What are you building?</h1>
        <p className="track-subtitle">
          This determines who you'll be matched with and what the platform looks like for you.
        </p>

        <div className="track-options">
          {TRACKS.map((t) => (
            <button
              key={t.id}
              className={`track-option ${selected === t.id ? "track-option-selected" : ""}`}
              style={selected === t.id ? { borderColor: t.color, boxShadow: `0 0 30px ${t.color}20` } : {}}
              onClick={() => setSelected(t.id)}
            >
              <span className="track-option-icon">{t.icon}</span>
              <span className="track-option-label">{t.label}</span>
              <span className="track-option-tagline">{t.tagline}</span>
              <span className="track-option-desc">{t.description}</span>
              {selected === t.id && (
                <span className="track-option-check" style={{ color: t.color }}>✓</span>
              )}
            </button>
          ))}
        </div>

        <button
          className="track-confirm"
          onClick={confirm}
          disabled={!selected || loading}
          style={selected ? { background: TRACKS.find((t) => t.id === selected)?.color } : {}}
        >
          {loading ? "Setting up..." : selected ? `Continue as ${TRACKS.find((t) => t.id === selected)?.label}` : "Select a track"}
        </button>

        <p className="track-footer">You can change this later in your profile settings.</p>
      </div>
    </div>
  );
}
