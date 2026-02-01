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
