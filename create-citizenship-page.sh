#!/bin/bash
# ============================================
# GroundUp — Citizenship page + API
# Run from: ~/groundup
# ============================================

set -e
echo "🇺🇸 Creating citizenship attestation..."

# ──────────────────────────────────────────────
# 1. Citizenship API
# ──────────────────────────────────────────────
mkdir -p app/api/citizenship

cat > app/api/citizenship/route.ts << 'EOF'
import { NextResponse } from "next/server";
import { auth } from "@clerk/nextjs/server";
import { prisma } from "@/lib/prisma";

export async function GET() {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const user = await prisma.user.findUnique({
    where: { clerkId },
    select: { usCitizenAttested: true, attestedAt: true, stateOfResidence: true },
  });

  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });
  return NextResponse.json(user);
}

export async function POST(req: Request) {
  const { userId: clerkId } = await auth();
  if (!clerkId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const body = await req.json();
  const { attest, stateOfResidence } = body;

  if (!attest) {
    return NextResponse.json(
      { error: "You must attest to US citizenship to use GroundUp" },
      { status: 403 }
    );
  }

  const user = await prisma.user.findUnique({ where: { clerkId }, select: { id: true } });
  if (!user) return NextResponse.json({ error: "User not found" }, { status: 404 });

  await prisma.user.update({
    where: { id: user.id },
    data: {
      usCitizenAttested: true,
      attestedAt: new Date(),
      stateOfResidence: stateOfResidence || null,
    },
  });

  return NextResponse.json({ attested: true });
}
EOF

echo "  ✓ Created /api/citizenship"

# ──────────────────────────────────────────────
# 2. Citizenship page
# ──────────────────────────────────────────────
mkdir -p app/citizenship

cat > app/citizenship/page.tsx << 'EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

const US_STATES = [
  "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA",
  "HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
  "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
  "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
  "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY","DC"
];

const STATE_NAMES: Record<string, string> = {
  AL:"Alabama",AK:"Alaska",AZ:"Arizona",AR:"Arkansas",CA:"California",
  CO:"Colorado",CT:"Connecticut",DE:"Delaware",FL:"Florida",GA:"Georgia",
  HI:"Hawaii",ID:"Idaho",IL:"Illinois",IN:"Indiana",IA:"Iowa",KS:"Kansas",
  KY:"Kentucky",LA:"Louisiana",ME:"Maine",MD:"Maryland",MA:"Massachusetts",
  MI:"Michigan",MN:"Minnesota",MS:"Mississippi",MO:"Missouri",MT:"Montana",
  NE:"Nebraska",NV:"Nevada",NH:"New Hampshire",NJ:"New Jersey",
  NM:"New Mexico",NY:"New York",NC:"North Carolina",ND:"North Dakota",
  OH:"Ohio",OK:"Oklahoma",OR:"Oregon",PA:"Pennsylvania",RI:"Rhode Island",
  SC:"South Carolina",SD:"South Dakota",TN:"Tennessee",TX:"Texas",
  UT:"Utah",VT:"Vermont",VA:"Virginia",WA:"Washington",
  WV:"West Virginia",WI:"Wisconsin",WY:"Wyoming",DC:"District of Columbia"
};

export default function CitizenshipPage() {
  const router = useRouter();
  const [checked, setChecked] = useState(false);
  const [state, setState] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function submit() {
    if (!checked) {
      setError("You must attest to US citizenship");
      return;
    }
    if (!state) {
      setError("Please select your state");
      return;
    }

    setLoading(true);
    setError("");

    try {
      const res = await fetch("/api/citizenship", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ attest: true, stateOfResidence: state }),
      });
      const data = await res.json();
      if (data.attested) {
        router.push("/select-track");
      } else {
        setError(data.error || "Failed to submit");
      }
    } catch {
      setError("Something went wrong");
    }
    setLoading(false);
  }

  return (
    <div className="citizen-container">
      <div className="citizen-card">
        <div className="citizen-flag">🇺🇸</div>
        <h1 className="citizen-title">US Citizens Only</h1>
        <p className="citizen-desc">
          GroundUp is currently available exclusively to United States citizens
          and permanent residents. By continuing, you attest that you meet this
          requirement.
        </p>

        <div className="citizen-form">
          <label className="citizen-state-label">State of Residence</label>
          <select
            className="citizen-select"
            value={state}
            onChange={(e) => setState(e.target.value)}
          >
            <option value="">— Select your state —</option>
            {US_STATES.map((s) => (
              <option key={s} value={s}>{STATE_NAMES[s]} ({s})</option>
            ))}
          </select>

          <label className="citizen-checkbox-row">
            <input
              type="checkbox"
              checked={checked}
              onChange={(e) => setChecked(e.target.checked)}
              className="citizen-checkbox"
            />
            <span className="citizen-attest-text">
              I attest that I am a United States citizen or permanent resident,
              and I understand that providing false information may result in
              account termination.
            </span>
          </label>

          {error && <div className="citizen-error">{error}</div>}

          <button
            className="citizen-submit"
            onClick={submit}
            disabled={!checked || !state || loading}
          >
            {loading ? "Submitting..." : "Continue to GroundUp"}
          </button>
        </div>

        <p className="citizen-footer">
          This restriction is required by our terms of service.
          Your attestation is recorded and may be subject to verification.
        </p>
      </div>
    </div>
  );
}
EOF

echo "  ✓ Created /citizenship page"

# ──────────────────────────────────────────────
# 3. CSS (only if not already present)
# ──────────────────────────────────────────────
if ! grep -q "citizen-container" app/globals.css 2>/dev/null; then
cat >> app/globals.css << 'CSSEOF'

/* ========================================
   CITIZENSHIP ATTESTATION PAGE
   ======================================== */

.citizen-container {
  min-height: 100vh;
  background: radial-gradient(circle at top center, #1e293b 0%, #020617 50%, #020617 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.citizen-card {
  max-width: 520px;
  width: 100%;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(100, 116, 139, 0.25);
  border-radius: 20px;
  padding: 48px 40px;
  text-align: center;
}

.citizen-flag {
  font-size: 3.5rem;
  margin-bottom: 16px;
}

.citizen-title {
  font-size: 1.75rem;
  font-weight: 800;
  color: #e5e7eb;
  margin-bottom: 12px;
}

.citizen-desc {
  color: #94a3b8;
  font-size: 0.9rem;
  line-height: 1.6;
  margin-bottom: 32px;
}

.citizen-form {
  text-align: left;
}

.citizen-state-label {
  display: block;
  font-size: 0.82rem;
  font-weight: 600;
  color: #94a3b8;
  margin-bottom: 8px;
}

.citizen-select {
  width: 100%;
  padding: 12px 16px;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(100, 116, 139, 0.3);
  border-radius: 10px;
  color: #e5e7eb;
  font-size: 0.9rem;
  margin-bottom: 20px;
  appearance: auto;
}

.citizen-select:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

.citizen-checkbox-row {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  cursor: pointer;
  padding: 16px;
  background: rgba(15, 23, 42, 0.4);
  border: 1px solid rgba(100, 116, 139, 0.2);
  border-radius: 10px;
  margin-bottom: 20px;
  transition: border-color 0.2s;
}

.citizen-checkbox-row:hover {
  border-color: rgba(59, 130, 246, 0.3);
}

.citizen-checkbox {
  width: 20px;
  height: 20px;
  margin-top: 2px;
  flex-shrink: 0;
  accent-color: #3b82f6;
}

.citizen-attest-text {
  font-size: 0.85rem;
  color: #cbd5e1;
  line-height: 1.5;
}

.citizen-error {
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.3);
  color: #f87171;
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 0.85rem;
  margin-bottom: 16px;
}

.citizen-submit {
  width: 100%;
  padding: 14px;
  background: linear-gradient(135deg, #3b82f6, #2563eb);
  color: white;
  font-weight: 700;
  font-size: 0.95rem;
  border: none;
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.3s ease;
}

.citizen-submit:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 6px 24px rgba(59, 130, 246, 0.4);
}

.citizen-submit:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.citizen-footer {
  margin-top: 24px;
  font-size: 0.75rem;
  color: #475569;
  line-height: 1.5;
}
CSSEOF

echo "  ✓ Appended citizenship CSS"
else
echo "  ✓ CSS already present"
fi

# ──────────────────────────────────────────────
# 4. Commit and push
# ──────────────────────────────────────────────
git add .
git commit -m "feat: citizenship attestation page + API

- /citizenship: state selector, sworn attestation checkbox
- /api/citizenship: GET status, POST attestation
- Redirects to /select-track after attestation
- Dashboard gate: redirects here if not attested"

git push origin main

echo ""
echo "✅ Citizenship page deployed!"
echo ""
echo "   Flow: Sign up → /citizenship → /select-track → /onboarding → /dashboard"
