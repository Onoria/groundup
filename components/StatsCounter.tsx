"use client";

import { useEffect, useState } from "react";

export default function StatsCounter() {
  const [stats, setStats] = useState({ activeUsers: 0, activeTeams: 0 });
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    fetch("/api/stats")
      .then((r) => r.json())
      .then((data) => {
        setStats(data);
        setLoaded(true);
      })
      .catch(() => setLoaded(true));
  }, []);

  return (
    <div className="stats-counter-row">
      <div className="stats-counter-item">
        <span className={`stats-counter-value ${loaded ? "stats-loaded" : ""}`}>
          {stats.activeUsers}
        </span>
        <span className="stats-counter-label">Active Founders</span>
      </div>
      <div className="stats-counter-divider" />
      <div className="stats-counter-item">
        <span className={`stats-counter-value stats-counter-teams ${loaded ? "stats-loaded" : ""}`}>
          {stats.activeTeams}
        </span>
        <span className="stats-counter-label">Teams Formed</span>
      </div>
    </div>
  );
}
