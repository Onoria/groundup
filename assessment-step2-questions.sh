#!/bin/bash
# ============================================
# GroundUp - Working Style Assessment: Step 2
# Seed 90 Questions (15 per dimension)
# Run from: ~/groundup
# ============================================

echo "🧠 Step 2: Seeding question bank..."

# Create seed script
cat > prisma/seed-questions.ts << 'SEEDEOF'
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

interface QuestionSeed {
  dimension: string;
  scenario: string;
  optionAText: string;
  optionBText: string;
  optionAScores: string;
  optionBScores: string;
}

const questions: QuestionSeed[] = [

  // ════════════════════════════════════════════════
  // RISK TOLERANCE (15 questions)
  // Low = Incremental Builder  |  High = Moonshot Thinker
  // ════════════════════════════════════════════════

  {
    dimension: "risk_tolerance",
    scenario: "You have two startup ideas. One solves a proven problem in a crowded market. The other tackles something nobody has attempted — but you're not sure there's demand yet.",
    optionAText: "Go after the unproven idea — if it works, there's no competition and the upside is massive.",
    optionBText: "Take the proven market — you know people will pay, and you can differentiate on execution.",
    optionAScores: JSON.stringify({ risk_tolerance: 10 }),
    optionBScores: JSON.stringify({ risk_tolerance: -10 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "Your startup is generating steady revenue at $15K/month. A VC offers $2M funding but wants you to 10x your burn rate and go after a much bigger market.",
    optionAText: "Take the funding — this is the chance to swing big and build something transformative.",
    optionBText: "Keep bootstrapping — the steady growth is working, and you keep full control.",
    optionAScores: JSON.stringify({ risk_tolerance: 10, role_gravity: -3 }),
    optionBScores: JSON.stringify({ risk_tolerance: -10, role_gravity: 3 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "You're about to launch. Your product handles 80% of use cases well, but has known gaps in edge cases.",
    optionAText: "Ship it now — get real users, learn fast, patch the gaps based on actual feedback.",
    optionBText: "Delay two more weeks to cover the edge cases — first impressions matter, and you don't want bad reviews.",
    optionAScores: JSON.stringify({ risk_tolerance: 8, pace: 5 }),
    optionBScores: JSON.stringify({ risk_tolerance: -8, pace: -5 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "Your biggest competitor just raised $50M. Some of your team is nervous. How do you respond?",
    optionAText: "This validates the market — double down. Their size will slow them down, and we can outmaneuver them.",
    optionBText: "Time to differentiate and find a niche they won't chase. We can't outspend them, so we need to outsmart them.",
    optionAScores: JSON.stringify({ risk_tolerance: 8 }),
    optionBScores: JSON.stringify({ risk_tolerance: -8 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "You discover a pivot opportunity that could 5x your market — but it means abandoning 6 months of work and your current users.",
    optionAText: "Pivot. Six months of sunk cost shouldn't dictate the future. The bigger opportunity is worth resetting.",
    optionBText: "Stay the course. Your current users trusted you, and pivoting too fast signals instability.",
    optionAScores: JSON.stringify({ risk_tolerance: 10 }),
    optionBScores: JSON.stringify({ risk_tolerance: -10 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "You need to hire your first engineer. One candidate is brilliant but volatile — past employers describe them as 'genius but difficult.' The other is solid, reliable, and collaborative.",
    optionAText: "Hire the brilliant one. At this stage, raw talent and speed matter more than harmony.",
    optionBText: "Hire the reliable one. Team culture compounds — one toxic dynamic can wreck an early team.",
    optionAScores: JSON.stringify({ risk_tolerance: 9, conflict_approach: 4 }),
    optionBScores: JSON.stringify({ risk_tolerance: -9, conflict_approach: -4 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "A huge enterprise client wants to sign — but their contract requires custom features that will detour your product roadmap by 3 months.",
    optionAText: "Sign it. The revenue and brand name are worth the detour. You can get back on track after.",
    optionBText: "Pass. Chasing one client's needs can derail your vision. Build for the market, not one buyer.",
    optionAScores: JSON.stringify({ risk_tolerance: -6, role_gravity: 5 }),
    optionBScores: JSON.stringify({ risk_tolerance: 6, role_gravity: -5 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "You're deciding between two pricing strategies: freemium with a long conversion funnel, or premium-only from day one with a higher barrier to entry.",
    optionAText: "Go premium — it filters for serious customers and validates willingness to pay immediately.",
    optionBText: "Go freemium — cast a wide net, build a user base, and convert over time.",
    optionAScores: JSON.stringify({ risk_tolerance: -5, decision_style: -4 }),
    optionBScores: JSON.stringify({ risk_tolerance: 5, decision_style: 4 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "Your co-founder wants to bet the company's remaining runway on one big marketing push — a major conference sponsorship that could land you in front of 10,000 potential users.",
    optionAText: "Do it. Calculated bets like this are how startups break through. Playing it safe won't get you noticed.",
    optionBText: "Too risky on one channel. Split the budget across multiple smaller experiments to find what works.",
    optionAScores: JSON.stringify({ risk_tolerance: 10 }),
    optionBScores: JSON.stringify({ risk_tolerance: -10 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "You have an idea to expand internationally — a huge market, but completely different regulations, language, and culture.",
    optionAText: "Go for it early. First movers in new markets build insurmountable leads. Figure it out as you go.",
    optionBText: "Dominate your home market first. International expansion is a distraction until you have product-market fit nailed.",
    optionAScores: JSON.stringify({ risk_tolerance: 9 }),
    optionBScores: JSON.stringify({ risk_tolerance: -9 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "An acqui-hire offer comes in: a big tech company will buy your startup for $3M and hire your team. You believe the company could be worth $50M in 3 years — but there's no guarantee.",
    optionAText: "Turn it down. You didn't start this to exit small. The upside potential is worth the risk.",
    optionBText: "Take it. $3M in hand beats a speculative $50M. You can always start another company.",
    optionAScores: JSON.stringify({ risk_tolerance: 10 }),
    optionBScores: JSON.stringify({ risk_tolerance: -10 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "Your MVP is getting traction, but a friend shows you emerging tech (AI, blockchain, etc.) that could make your current approach obsolete within a year.",
    optionAText: "Rebuild on the new tech now, before competitors do. Being early to a paradigm shift is how you win.",
    optionBText: "Keep building what's working. New tech is overhyped more often than not — your users care about the product, not the stack.",
    optionAScores: JSON.stringify({ risk_tolerance: 9, decision_style: 5 }),
    optionBScores: JSON.stringify({ risk_tolerance: -9, decision_style: -5 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "You need a co-founder. One option is a close friend you trust completely but who has no startup experience. The other is a stranger with an incredible track record but you've only met twice.",
    optionAText: "The experienced stranger. At this stage you need competence, and trust can be built.",
    optionBText: "Your friend. Trust is the hardest thing to build. Skills can be learned, but loyalty can't.",
    optionAScores: JSON.stringify({ risk_tolerance: 8 }),
    optionBScores: JSON.stringify({ risk_tolerance: -8 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "You're running out of runway in 4 months. Do you focus entirely on fundraising, or keep building and try to reach profitability?",
    optionAText: "Build toward profitability. Revenue is the ultimate fundraising leverage — or you won't need to raise at all.",
    optionBText: "Focus on fundraising. Four months is tight, and running out of cash kills companies no matter how good the product is.",
    optionAScores: JSON.stringify({ risk_tolerance: 7, role_gravity: 5 }),
    optionBScores: JSON.stringify({ risk_tolerance: -7, role_gravity: -5 }),
  },
  {
    dimension: "risk_tolerance",
    scenario: "A key team member wants to experiment with a radically different product direction during a hack week. It's unrelated to your roadmap but they're passionate about it.",
    optionAText: "Encourage it. Some of the best products started as side projects. Give them the freedom to explore.",
    optionBText: "Redirect that energy toward the roadmap. Focus is everything right now — save experiments for later.",
    optionAScores: JSON.stringify({ risk_tolerance: 7, pace: 3 }),
    optionBScores: JSON.stringify({ risk_tolerance: -7, pace: -3 }),
  },

  // ════════════════════════════════════════════════
  // DECISION STYLE (15 questions)
  // Low = Data & Analysis  |  High = Gut Instinct & Speed
  // ════════════════════════════════════════════════

  {
    dimension: "decision_style",
    scenario: "You're choosing between two feature ideas. You have strong intuition about which one users want, but your analytics suggest the other one gets more engagement.",
    optionAText: "Trust the data. That's the whole point of tracking metrics — to override assumptions with evidence.",
    optionBText: "Trust your intuition. Analytics capture what happened, not what's possible. Sometimes you have to lead users.",
    optionAScores: JSON.stringify({ decision_style: -10 }),
    optionBScores: JSON.stringify({ decision_style: 10 }),
  },
  {
    dimension: "decision_style",
    scenario: "A partnership opportunity lands on your desk. The terms are good but you need to decide by tomorrow. You don't have time for thorough due diligence.",
    optionAText: "Take it. Your read on the people and the opportunity is strong. Speed matters in partnerships.",
    optionBText: "Ask for more time. If they won't give it, walk away. Rushed decisions lead to regret.",
    optionAScores: JSON.stringify({ decision_style: 10, risk_tolerance: 4 }),
    optionBScores: JSON.stringify({ decision_style: -10, risk_tolerance: -4 }),
  },
  {
    dimension: "decision_style",
    scenario: "Your team is debating which market segment to target first. There's no clear data winner — both segments show similar potential.",
    optionAText: "Pick the one that excites you more. When data is ambiguous, conviction and energy become the differentiator.",
    optionBText: "Run a small test in both segments for two weeks. Let the results choose for you.",
    optionAScores: JSON.stringify({ decision_style: 9 }),
    optionBScores: JSON.stringify({ decision_style: -9 }),
  },
  {
    dimension: "decision_style",
    scenario: "You're designing your pricing page. Do you A/B test five variations over a month, or go with what feels right based on competitor research and customer conversations?",
    optionAText: "A/B test. Pricing is too important to guess on — let the numbers tell you what converts.",
    optionBText: "Go with your best judgment and launch. You can always adjust pricing later based on real sales conversations.",
    optionAScores: JSON.stringify({ decision_style: -10 }),
    optionBScores: JSON.stringify({ decision_style: 10 }),
  },
  {
    dimension: "decision_style",
    scenario: "A potential hire interviews well and your gut says they're great, but their references are lukewarm — 'good, not great.'",
    optionAText: "Trust the references. People put their best foot forward in interviews; references reveal the day-to-day.",
    optionBText: "Trust your gut. References are often political. You spent hours with this person and saw something real.",
    optionAScores: JSON.stringify({ decision_style: -9 }),
    optionBScores: JSON.stringify({ decision_style: 9 }),
  },
  {
    dimension: "decision_style",
    scenario: "You're about to make a major product decision. Your advisor says 'sleep on it.' Your instinct says you already know the answer.",
    optionAText: "Sleep on it. Impulse decisions feel right in the moment but look different after reflection.",
    optionBText: "Decide now. You've been thinking about this for weeks already — more time just creates doubt.",
    optionAScores: JSON.stringify({ decision_style: -8, pace: -4 }),
    optionBScores: JSON.stringify({ decision_style: 8, pace: 4 }),
  },
  {
    dimension: "decision_style",
    scenario: "Your startup's churn rate just spiked. You have three theories about why, but only time and budget to investigate one thoroughly.",
    optionAText: "Dig deep into the data — exit surveys, cohort analysis, usage patterns. Find the root cause before acting.",
    optionBText: "Go with the theory that resonates most with what you've heard from customers and ship a fix fast.",
    optionAScores: JSON.stringify({ decision_style: -10, pace: -3 }),
    optionBScores: JSON.stringify({ decision_style: 10, pace: 3 }),
  },
  {
    dimension: "decision_style",
    scenario: "You're pitching investors. One asks a question you didn't prepare for. Do you:",
    optionAText: "Acknowledge you don't have that data point handy and offer to follow up with specifics after the meeting.",
    optionBText: "Give your honest best estimate based on what you know, with the caveat that you'll confirm the exact numbers.",
    optionAScores: JSON.stringify({ decision_style: -7 }),
    optionBScores: JSON.stringify({ decision_style: 7 }),
  },
  {
    dimension: "decision_style",
    scenario: "Two customers give you opposite feedback about the same feature. Customer A wants it simpler. Customer B wants it more powerful.",
    optionAText: "Look at the usage data. See which use pattern is more common and optimize for the majority.",
    optionBText: "Think about your vision for the product. Which direction aligns with where you want to take things?",
    optionAScores: JSON.stringify({ decision_style: -9, role_gravity: 4 }),
    optionBScores: JSON.stringify({ decision_style: 9, role_gravity: -4 }),
  },
  {
    dimension: "decision_style",
    scenario: "You're choosing a tech stack for your new project. There's a hot new framework everyone's talking about, and a battle-tested one with years of documentation.",
    optionAText: "Battle-tested. The boring choice is boring for a reason — it works, and debugging is well-documented.",
    optionBText: "The new framework. If the developer community is excited, there's usually a reason. Early adopters get advantages.",
    optionAScores: JSON.stringify({ decision_style: -8, risk_tolerance: -4 }),
    optionBScores: JSON.stringify({ decision_style: 8, risk_tolerance: 4 }),
  },
  {
    dimension: "decision_style",
    scenario: "Your co-founder presents a spreadsheet model projecting 3 scenarios for the next year. You think one key assumption is wrong but can't prove it.",
    optionAText: "Defer to the model. Structured analysis beats hunches, even imperfect analysis.",
    optionBText: "Challenge the assumption openly. Models are only as good as their inputs, and experience counts.",
    optionAScores: JSON.stringify({ decision_style: -8 }),
    optionBScores: JSON.stringify({ decision_style: 8, conflict_approach: 4 }),
  },
  {
    dimension: "decision_style",
    scenario: "You're negotiating a deal. The other side's offer is fair by market standards, but something about it doesn't feel right to you.",
    optionAText: "Trust the feeling. Walk away or renegotiate. Your subconscious is picking up on something the spreadsheet isn't.",
    optionBText: "Stick with the market data. Fair is fair — don't let vague discomfort kill a good deal.",
    optionAScores: JSON.stringify({ decision_style: 9 }),
    optionBScores: JSON.stringify({ decision_style: -9 }),
  },
  {
    dimension: "decision_style",
    scenario: "You need to decide on your company's name. You've narrowed it to two options. One tested better in a survey, but the other one gives you chills.",
    optionAText: "Go with the one that gives you chills. A name needs to inspire the founders first — the market will follow.",
    optionBText: "Go with the survey winner. You're building for customers, not for yourself. Let the audience decide.",
    optionAScores: JSON.stringify({ decision_style: 10 }),
    optionBScores: JSON.stringify({ decision_style: -10 }),
  },
  {
    dimension: "decision_style",
    scenario: "Your marketing team wants to try a campaign that's unconventional and hard to measure. The creative is great, but you can't set up clear attribution.",
    optionAText: "Run it anyway. Not everything valuable is measurable. Brand and culture matter.",
    optionBText: "Rework it until it's measurable. If you can't measure it, you can't learn from it or justify scaling it.",
    optionAScores: JSON.stringify({ decision_style: 8 }),
    optionBScores: JSON.stringify({ decision_style: -8 }),
  },
  {
    dimension: "decision_style",
    scenario: "You're stuck between two strategic directions. Your mentor says 'make a decision framework and score each option objectively.' Your other advisor says 'imagine it's five years from now — which choice would you regret not making?'",
    optionAText: "Build the decision framework. Structure prevents bias and helps you explain the choice to stakeholders.",
    optionBText: "Use the regret test. The emotional weight of a decision often reveals what matters more than a scoring matrix.",
    optionAScores: JSON.stringify({ decision_style: -10 }),
    optionBScores: JSON.stringify({ decision_style: 10 }),
  },

  // ════════════════════════════════════════════════
  // PACE (15 questions)
  // Low = Steady Marathon  |  High = Sprint & Rest
  // ════════════════════════════════════════════════

  {
    dimension: "pace",
    scenario: "It's launch week. Your team is exhausted from a two-week sprint. The product is 95% ready. Do you push through, or take a breather and launch Monday?",
    optionAText: "Push through. The momentum is here, the energy is high, and shipping matters more than perfect timing.",
    optionBText: "Rest and launch Monday. A burned-out team will make mistakes, and Monday gives you a clean start.",
    optionAScores: JSON.stringify({ pace: 10 }),
    optionBScores: JSON.stringify({ pace: -10 }),
  },
  {
    dimension: "pace",
    scenario: "You're planning your Q2 roadmap. Do you commit to 3 major features with aggressive deadlines, or 6 smaller improvements on a comfortable timeline?",
    optionAText: "Three big bets with tight deadlines. Ambition drives teams and big features move the needle.",
    optionBText: "Six smaller wins. Consistent improvement compounds, and hitting targets keeps morale high.",
    optionAScores: JSON.stringify({ pace: 9 }),
    optionBScores: JSON.stringify({ pace: -9 }),
  },
  {
    dimension: "pace",
    scenario: "Your co-founder just worked 80 hours this week and is on fire — shipping features left and right. You're worried about burnout.",
    optionAText: "Let them ride the wave. Creative energy comes in bursts. They'll rest naturally when the sprint is over.",
    optionBText: "Have a conversation about sustainability. Burnout sneaks up, and you need them for the long haul.",
    optionAScores: JSON.stringify({ pace: 8 }),
    optionBScores: JSON.stringify({ pace: -8, conflict_approach: -3 }),
  },
  {
    dimension: "pace",
    scenario: "You have a list of 20 things that need to get done this month. How do you approach it?",
    optionAText: "Prioritize ruthlessly — pick the top 5, go all-in on those, ignore the rest until they're done.",
    optionBText: "Spread the work evenly — chip away at all 20 a little each day so nothing falls behind.",
    optionAScores: JSON.stringify({ pace: 9, decision_style: 5 }),
    optionBScores: JSON.stringify({ pace: -9, decision_style: -5 }),
  },
  {
    dimension: "pace",
    scenario: "It's Friday afternoon. You've hit your weekly goals. An exciting new idea just popped up. Do you start on it now or save it for Monday?",
    optionAText: "Start now while the excitement is fresh. Momentum is rare — capture it.",
    optionBText: "Save it. Protecting your downtime makes you sharper on Monday. The idea will still be good.",
    optionAScores: JSON.stringify({ pace: 8 }),
    optionBScores: JSON.stringify({ pace: -8 }),
  },
  {
    dimension: "pace",
    scenario: "Your startup just got featured in a major publication. Signups are spiking. How do you respond?",
    optionAText: "All hands on deck. Drop everything non-essential and capitalize. Windows like this close fast.",
    optionBText: "Stay the course. Process the signups well, but don't derail your plans for a spike that might not last.",
    optionAScores: JSON.stringify({ pace: 10, risk_tolerance: 4 }),
    optionBScores: JSON.stringify({ pace: -10, risk_tolerance: -4 }),
  },
  {
    dimension: "pace",
    scenario: "Your team just finished a huge launch. Barely 48 hours later, a competitor announces a similar feature. Your instinct is to:",
    optionAText: "Start the next sprint immediately. Stay ahead — resting now means losing the lead.",
    optionBText: "Debrief, celebrate, and recover first. Reactive sprints lead to poor decisions.",
    optionAScores: JSON.stringify({ pace: 10 }),
    optionBScores: JSON.stringify({ pace: -10 }),
  },
  {
    dimension: "pace",
    scenario: "You're building a demo for a potential investor meeting in 2 weeks. How do you structure the work?",
    optionAText: "Plan the work evenly across both weeks with daily check-ins to stay on track.",
    optionBText: "Explore and prototype loosely in week one, then do an intense build sprint in week two.",
    optionAScores: JSON.stringify({ pace: -9 }),
    optionBScores: JSON.stringify({ pace: 9 }),
  },
  {
    dimension: "pace",
    scenario: "Your personal productivity pattern is closest to:",
    optionAText: "Intense bursts of 4-6 hours of deep work followed by guilt-free downtime.",
    optionBText: "Consistent 7-8 hour days with steady output and clear boundaries.",
    optionAScores: JSON.stringify({ pace: 10 }),
    optionBScores: JSON.stringify({ pace: -10 }),
  },
  {
    dimension: "pace",
    scenario: "You're behind on a milestone. Your team suggests working the weekend to catch up. How do you feel about it?",
    optionAText: "Let's do it. Short-term sacrifice for a critical goal. We'll take time off after.",
    optionBText: "No. Weekends are recovery time. We adjust the timeline instead of burning the team out.",
    optionAScores: JSON.stringify({ pace: 9 }),
    optionBScores: JSON.stringify({ pace: -9 }),
  },
  {
    dimension: "pace",
    scenario: "You have a choice: release a good-enough update every week, or a polished update once a month.",
    optionAText: "Weekly. Ship fast, iterate fast. Users prefer frequent progress over rare perfection.",
    optionBText: "Monthly. Quality builds trust. Shipping half-baked work erodes confidence in the product.",
    optionAScores: JSON.stringify({ pace: 8, risk_tolerance: 3 }),
    optionBScores: JSON.stringify({ pace: -8, risk_tolerance: -3 }),
  },
  {
    dimension: "pace",
    scenario: "You're onboarding a new team member. Do you prefer they ramp up quickly with intense immersion, or gradually over a few weeks?",
    optionAText: "Immersion. Pair them with someone senior, throw them into real work day one. Best way to learn.",
    optionBText: "Gradual. Let them absorb the codebase, culture, and processes. Rushing creates gaps.",
    optionAScores: JSON.stringify({ pace: 7 }),
    optionBScores: JSON.stringify({ pace: -7 }),
  },
  {
    dimension: "pace",
    scenario: "Your morning routine looks more like:",
    optionAText: "Check messages, scan the landscape, jump into whatever feels most urgent or exciting.",
    optionBText: "Follow a consistent routine — same order, same times. It keeps the day predictable and focused.",
    optionAScores: JSON.stringify({ pace: 7, decision_style: 4 }),
    optionBScores: JSON.stringify({ pace: -7, decision_style: -4 }),
  },
  {
    dimension: "pace",
    scenario: "Your product roadmap has a 'nice to have' feature that customers keep requesting. It's not urgent. When do you build it?",
    optionAText: "Sneak it into the next sprint when you have momentum. Quick win while energy is high.",
    optionBText: "Schedule it properly for next quarter. Everything gets its turn in the pipeline.",
    optionAScores: JSON.stringify({ pace: 8 }),
    optionBScores: JSON.stringify({ pace: -8 }),
  },
  {
    dimension: "pace",
    scenario: "How do you handle creative blocks?",
    optionAText: "Walk away completely. Do something else, sleep on it, come back fresh. Forcing creativity doesn't work.",
    optionBText: "Push through. Set a timer, stay in the chair, produce something — even if it's bad. Momentum creates quality.",
    optionAScores: JSON.stringify({ pace: -7 }),
    optionBScores: JSON.stringify({ pace: 7 }),
  },

  // ════════════════════════════════════════════════
  // CONFLICT APPROACH (15 questions)
  // Low = Diplomatic Consensus  |  High = Direct Confrontation
  // ════════════════════════════════════════════════

  {
    dimension: "conflict_approach",
    scenario: "Your co-founder made a decision you disagree with while you were away. It's already been communicated to the team.",
    optionAText: "Pull them aside immediately. You need to hash this out before it goes further.",
    optionBText: "Let it play out for now. Undermining their decision publicly would be worse. Discuss it privately later.",
    optionAScores: JSON.stringify({ conflict_approach: 10 }),
    optionBScores: JSON.stringify({ conflict_approach: -10 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "During a team meeting, a developer pushes back hard on your product decision. Their tone is borderline disrespectful.",
    optionAText: "Address it head on in the meeting. Say something like 'I hear the disagreement, let's talk through the reasoning right now.'",
    optionBText: "Stay calm, move the meeting forward, and have a one-on-one conversation with them afterward about both the decision and the tone.",
    optionAScores: JSON.stringify({ conflict_approach: 9 }),
    optionBScores: JSON.stringify({ conflict_approach: -9, communication: -3 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "You notice tension between two team members that's affecting productivity. Neither has brought it up.",
    optionAText: "Name it directly. Bring them together and say 'I've noticed friction. Let's talk about it and fix it.'",
    optionBText: "Address it indirectly. Adjust workflows to reduce their overlap, and check in with each privately to understand the dynamic.",
    optionAScores: JSON.stringify({ conflict_approach: 10 }),
    optionBScores: JSON.stringify({ conflict_approach: -10 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "Your investor gives you advice you think is completely wrong. They're well-intentioned but out of touch with your market.",
    optionAText: "Be honest. Thank them but clearly explain why you see it differently, with specifics.",
    optionBText: "Thank them warmly, take notes, and quietly proceed with your own plan. No need for confrontation.",
    optionAScores: JSON.stringify({ conflict_approach: 8 }),
    optionBScores: JSON.stringify({ conflict_approach: -8 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "A vendor has been underdelivering for weeks. They keep making excuses. You need to address it.",
    optionAText: "Be blunt. 'We're not getting what we're paying for. Here's what needs to change by Friday or we're looking elsewhere.'",
    optionBText: "Frame it constructively. 'Let's revisit our agreement and find a path that works for both of us. What support do you need?'",
    optionAScores: JSON.stringify({ conflict_approach: 10 }),
    optionBScores: JSON.stringify({ conflict_approach: -10 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "You and your co-founder disagree about equity split for a new team member. The conversation is getting tense.",
    optionAText: "Keep talking it through now. Tense conversations that get postponed only get worse.",
    optionBText: "Suggest tabling it until tomorrow. Fresh eyes and cooler heads make better equity decisions.",
    optionAScores: JSON.stringify({ conflict_approach: 9, pace: 5 }),
    optionBScores: JSON.stringify({ conflict_approach: -9, pace: -5 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "A team member consistently misses deadlines but does great work when they deliver. How do you handle it?",
    optionAText: "Direct conversation: 'Your work quality is excellent, but the missed deadlines are impacting the team. What's going on?'",
    optionBText: "Adjust the system around them. Give them earlier internal deadlines, pair them with someone organized, reduce their workload.",
    optionAScores: JSON.stringify({ conflict_approach: 8, communication: 4 }),
    optionBScores: JSON.stringify({ conflict_approach: -8, communication: -4 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "During a pitch, a potential partner criticizes your business model in front of their whole team. Some of their points are valid.",
    optionAText: "Acknowledge what's fair, push back on what isn't. Show you can take criticism and defend your thinking.",
    optionBText: "Stay gracious, take all the feedback, and regroup later. Arguing in their conference room won't win the deal.",
    optionAScores: JSON.stringify({ conflict_approach: 7 }),
    optionBScores: JSON.stringify({ conflict_approach: -7 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "You overhear a team member complaining about a company decision to another colleague. The complaint has some merit.",
    optionAText: "Walk over and engage. 'I heard that — let's talk about it. Your perspective matters and I want to understand.'",
    optionBText: "Create a feedback channel. Send a team-wide message encouraging open feedback, without singling anyone out.",
    optionAScores: JSON.stringify({ conflict_approach: 9 }),
    optionBScores: JSON.stringify({ conflict_approach: -9 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "You made a mistake that cost the company a client. Your team doesn't know the details yet.",
    optionAText: "Own it publicly in the next team meeting. Full transparency — explain what happened and what you're doing differently.",
    optionBText: "Fix it quietly first. Once you have a solution, share the lesson learned without dramatic self-flagellation.",
    optionAScores: JSON.stringify({ conflict_approach: 9, communication: 4 }),
    optionBScores: JSON.stringify({ conflict_approach: -9, communication: -4 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "A close advisor introduces you to a potential co-founder. After two meetings, you realize it's not a fit. The advisor is excited about the match.",
    optionAText: "Tell both the advisor and the candidate directly. Better to be honest now than waste everyone's time.",
    optionBText: "Let the conversation taper off naturally. There's no need to create an awkward situation with your advisor.",
    optionAScores: JSON.stringify({ conflict_approach: 10 }),
    optionBScores: JSON.stringify({ conflict_approach: -10 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "Your co-founder keeps bringing up a strategy you both agreed to shelve last month. It's starting to feel like they never accepted the decision.",
    optionAText: "Call it out directly. 'It feels like you didn't fully buy into shelving this. Can we talk about what's really going on?'",
    optionBText: "Reaffirm the original reasoning gently. Share updated data that supports the current direction.",
    optionAScores: JSON.stringify({ conflict_approach: 10 }),
    optionBScores: JSON.stringify({ conflict_approach: -10, decision_style: -4 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "Your team is split 50/50 on a decision. Discussion has gone back and forth for days.",
    optionAText: "Make the call. As the leader, persistent deadlocks need someone to decide and take accountability.",
    optionBText: "Find a compromise that incorporates elements of both sides. Consensus matters more than speed here.",
    optionAScores: JSON.stringify({ conflict_approach: 8, decision_style: 5 }),
    optionBScores: JSON.stringify({ conflict_approach: -8, decision_style: -5 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "An early employee asks for a raise you can't afford. They've been critical to the company's success.",
    optionAText: "Be transparent about the finances. Show them the numbers. Discuss equity, future raises, and what triggers would unlock more comp.",
    optionBText: "Find creative alternatives without exposing financials. Extra PTO, title change, equity adjustment, flexible schedule.",
    optionAScores: JSON.stringify({ conflict_approach: 7 }),
    optionBScores: JSON.stringify({ conflict_approach: -7 }),
  },
  {
    dimension: "conflict_approach",
    scenario: "Your best friend applies to join your startup but isn't qualified for the role. They assume they'll get it.",
    optionAText: "Have the hard conversation now. 'I love our friendship and I want to be honest with you about the fit for this role.'",
    optionBText: "Offer them a different role that matches their skills, or suggest they apply when a better-fitting position opens.",
    optionAScores: JSON.stringify({ conflict_approach: 10 }),
    optionBScores: JSON.stringify({ conflict_approach: -10 }),
  },

  // ════════════════════════════════════════════════
  // ROLE GRAVITY (15 questions)
  // Low = Visionary / Strategy  |  High = Executor / Operations
  // ════════════════════════════════════════════════

  {
    dimension: "role_gravity",
    scenario: "It's Monday morning. You open your laptop. What energizes you more?",
    optionAText: "Mapping out the next quarter's strategy and thinking about where the market is heading.",
    optionBText: "Clearing the task list, unblocking the team, and making sure this week's ship date is on track.",
    optionAScores: JSON.stringify({ role_gravity: -10 }),
    optionBScores: JSON.stringify({ role_gravity: 10 }),
  },
  {
    dimension: "role_gravity",
    scenario: "Your startup is at a crossroads: invest in a new product line or optimize the existing one for profitability. Which gets you excited?",
    optionAText: "New product line. Exploring new territory and creating something from nothing is what gets me up in the morning.",
    optionBText: "Optimizing what works. Taking something good and making it great through systematic improvement is deeply satisfying.",
    optionAScores: JSON.stringify({ role_gravity: -10 }),
    optionBScores: JSON.stringify({ role_gravity: 10 }),
  },
  {
    dimension: "role_gravity",
    scenario: "In a team brainstorm, which role do you naturally gravitate toward?",
    optionAText: "The person generating wild ideas, connecting dots others don't see, and pushing the thinking further.",
    optionBText: "The person asking 'how would we actually build this?' and turning ideas into actionable plans.",
    optionAScores: JSON.stringify({ role_gravity: -10 }),
    optionBScores: JSON.stringify({ role_gravity: 10 }),
  },
  {
    dimension: "role_gravity",
    scenario: "You're describing your ideal workday. Which sounds closer?",
    optionAText: "A mix of customer conversations, whiteboard sessions, and writing about where the industry is going.",
    optionBText: "A mix of code reviews, process improvements, metrics dashboards, and clearing blockers for the team.",
    optionAScores: JSON.stringify({ role_gravity: -9 }),
    optionBScores: JSON.stringify({ role_gravity: 9 }),
  },
  {
    dimension: "role_gravity",
    scenario: "Your company just hit a major growth milestone. What's your instinct?",
    optionAText: "Start thinking about what's next — new markets, new products, the bigger picture.",
    optionBText: "Make sure the systems and team can handle the growth. Scale the ops before chasing the next thing.",
    optionAScores: JSON.stringify({ role_gravity: -9 }),
    optionBScores: JSON.stringify({ role_gravity: 9 }),
  },
  {
    dimension: "role_gravity",
    scenario: "A journalist asks what makes your startup special. What do you lead with?",
    optionAText: "The vision — the problem you're solving, why it matters, and how the world will be different.",
    optionBText: "The execution — your team, your metrics, your speed of shipping, and the results you're delivering.",
    optionAScores: JSON.stringify({ role_gravity: -10 }),
    optionBScores: JSON.stringify({ role_gravity: 10 }),
  },
  {
    dimension: "role_gravity",
    scenario: "You're reviewing the product backlog. What catches your eye first?",
    optionAText: "The strategic initiatives — new features that open up new markets or user segments.",
    optionBText: "The tech debt and reliability items — things that make the current product better and more stable.",
    optionAScores: JSON.stringify({ role_gravity: -8 }),
    optionBScores: JSON.stringify({ role_gravity: 8 }),
  },
  {
    dimension: "role_gravity",
    scenario: "Your team has a free 'innovation day.' What do you spend it on?",
    optionAText: "Researching trends, sketching a new product concept, or talking to potential users about unmet needs.",
    optionBText: "Automating a tedious workflow, improving the CI pipeline, or documenting processes that exist only in people's heads.",
    optionAScores: JSON.stringify({ role_gravity: -9 }),
    optionBScores: JSON.stringify({ role_gravity: 9 }),
  },
  {
    dimension: "role_gravity",
    scenario: "Which compliment from a colleague would mean more to you?",
    optionAText: "'Your vision for where this could go completely changed how I think about our product.'",
    optionBText: "'The way you organized this project was incredible. Everything ran like clockwork because of you.'",
    optionAScores: JSON.stringify({ role_gravity: -10 }),
    optionBScores: JSON.stringify({ role_gravity: 10 }),
  },
  {
    dimension: "role_gravity",
    scenario: "You're writing a blog post about your startup journey. The topic you're most drawn to:",
    optionAText: "Why this market needs to be disrupted and how your company's thesis challenges conventional thinking.",
    optionBText: "How you built your team, your processes, and the specific systems that power your company's output.",
    optionAScores: JSON.stringify({ role_gravity: -8 }),
    optionBScores: JSON.stringify({ role_gravity: 8 }),
  },
  {
    dimension: "role_gravity",
    scenario: "You have to delegate one of these two tasks. Which do you hand off?",
    optionAText: "The operational planning — weekly standups, sprint planning, resource allocation.",
    optionBText: "The investor narrative — pitch deck updates, the company story, market positioning.",
    optionAScores: JSON.stringify({ role_gravity: -9 }),
    optionBScores: JSON.stringify({ role_gravity: 9 }),
  },
  {
    dimension: "role_gravity",
    scenario: "Your favorite part of building a product is:",
    optionAText: "The 0-to-1 phase. Napkin sketches, first prototypes, figuring out if the idea has legs.",
    optionBText: "The 1-to-100 phase. Scaling what works, building the machine, watching metrics climb.",
    optionAScores: JSON.stringify({ role_gravity: -10 }),
    optionBScores: JSON.stringify({ role_gravity: 10 }),
  },
  {
    dimension: "role_gravity",
    scenario: "When things go wrong, your instinct is to:",
    optionAText: "Zoom out. Ask whether this failure reveals a deeper strategic problem or a market shift.",
    optionBText: "Zoom in. Find the root cause, fix the immediate issue, and put a process in place to prevent it.",
    optionAScores: JSON.stringify({ role_gravity: -9, decision_style: 3 }),
    optionBScores: JSON.stringify({ role_gravity: 9, decision_style: -3 }),
  },
  {
    dimension: "role_gravity",
    scenario: "You're hiring a #2 to complement you. Who do you look for?",
    optionAText: "Someone who can build and ship — turn my ideas into reality with discipline and speed.",
    optionBText: "Someone who can see around corners — provide the vision while I make things run.",
    optionAScores: JSON.stringify({ role_gravity: -8 }),
    optionBScores: JSON.stringify({ role_gravity: 8 }),
  },
  {
    dimension: "role_gravity",
    scenario: "At the end of a productive day, what gives you the deepest sense of satisfaction?",
    optionAText: "Having a breakthrough idea or insight that reframes how you think about the business.",
    optionBText: "Having shipped something real — code deployed, deal closed, process implemented.",
    optionAScores: JSON.stringify({ role_gravity: -10 }),
    optionBScores: JSON.stringify({ role_gravity: 10 }),
  },

  // ════════════════════════════════════════════════
  // COMMUNICATION (15 questions)
  // Low = Async / Written  |  High = Sync / Verbal
  // ════════════════════════════════════════════════

  {
    dimension: "communication",
    scenario: "You need to share a complex strategic update with your team. How do you deliver it?",
    optionAText: "Write a detailed memo or document. Let people read, digest, and respond in their own time.",
    optionBText: "Call a team meeting. Walk through it live so you can read reactions and answer questions in real time.",
    optionAScores: JSON.stringify({ communication: -10 }),
    optionBScores: JSON.stringify({ communication: 10 }),
  },
  {
    dimension: "communication",
    scenario: "A tricky problem comes up that needs input from three people. What do you do?",
    optionAText: "Create a shared doc or thread. Let each person contribute their thinking asynchronously.",
    optionBText: "Set up a quick 20-minute call. Three people in a room solve things faster than a comment thread.",
    optionAScores: JSON.stringify({ communication: -10 }),
    optionBScores: JSON.stringify({ communication: 10 }),
  },
  {
    dimension: "communication",
    scenario: "You're making a decision that affects the whole team. How do you get buy-in?",
    optionAText: "Write up the proposal with context and reasoning, share it, and give people 48 hours to weigh in.",
    optionBText: "Present it in a team meeting, explain your reasoning, and open the floor for real-time discussion.",
    optionAScores: JSON.stringify({ communication: -9 }),
    optionBScores: JSON.stringify({ communication: 9 }),
  },
  {
    dimension: "communication",
    scenario: "It's 10 AM and you have a question for a teammate. They're online. Do you:",
    optionAText: "Send a Slack message. They can respond when they're at a natural stopping point.",
    optionBText: "Hop on a quick call. It'll take 2 minutes verbally vs. 10 minutes of back-and-forth text.",
    optionAScores: JSON.stringify({ communication: -8 }),
    optionBScores: JSON.stringify({ communication: 8 }),
  },
  {
    dimension: "communication",
    scenario: "After a customer call, how do you share the insights with your team?",
    optionAText: "Write up structured notes with key quotes, action items, and tag relevant people.",
    optionBText: "Do a quick debrief call with the team while the conversation is fresh. Notes can come later.",
    optionAScores: JSON.stringify({ communication: -9 }),
    optionBScores: JSON.stringify({ communication: 9 }),
  },
  {
    dimension: "communication",
    scenario: "You're onboarding a new hire. How do you prefer to transfer knowledge?",
    optionAText: "Comprehensive documentation, recorded walkthroughs, and a self-paced learning path.",
    optionBText: "Pair them with a team member for the first week. Live walkthroughs and real-time Q&A.",
    optionAScores: JSON.stringify({ communication: -9 }),
    optionBScores: JSON.stringify({ communication: 9 }),
  },
  {
    dimension: "communication",
    scenario: "Your weekly team sync feels unproductive. How do you fix it?",
    optionAText: "Replace it with an async standup — everyone posts updates in a thread by noon.",
    optionBText: "Restructure the meeting — tighter agenda, time-boxes, and make sure it's discussion, not status updates.",
    optionAScores: JSON.stringify({ communication: -10 }),
    optionBScores: JSON.stringify({ communication: 10 }),
  },
  {
    dimension: "communication",
    scenario: "You have feedback for your co-founder about their presentation style. How do you deliver it?",
    optionAText: "Write it up thoughtfully. Specific examples, suggestions, delivered via message so they can process privately.",
    optionBText: "Grab coffee and talk through it face to face. Tone and body language matter for sensitive feedback.",
    optionAScores: JSON.stringify({ communication: -8 }),
    optionBScores: JSON.stringify({ communication: 8, conflict_approach: 3 }),
  },
  {
    dimension: "communication",
    scenario: "You're brainstorming solutions to a hard problem. What works best for you?",
    optionAText: "Solo thinking time first — write down your ideas, then share and discuss.",
    optionBText: "Live brainstorm session. Ideas build on each other in real time, and energy drives creativity.",
    optionAScores: JSON.stringify({ communication: -9 }),
    optionBScores: JSON.stringify({ communication: 9 }),
  },
  {
    dimension: "communication",
    scenario: "A disagreement is brewing over Slack. Messages are getting longer and more intense. What do you do?",
    optionAText: "Keep it in writing. Text forces clarity and creates a record. Meetings let emotions take over.",
    optionBText: "Move it to a call immediately. Text is causing misinterpretation, and voices resolve tension faster.",
    optionAScores: JSON.stringify({ communication: -8 }),
    optionBScores: JSON.stringify({ communication: 8, conflict_approach: 4 }),
  },
  {
    dimension: "communication",
    scenario: "You need to give your team a difficult update — you lost a major client. How do you share the news?",
    optionAText: "Write a transparent email or message. Give people the facts and space to process before discussing next steps.",
    optionBText: "Call an emergency team meeting. Deliver it personally, take questions live, and plan the response together.",
    optionAScores: JSON.stringify({ communication: -9 }),
    optionBScores: JSON.stringify({ communication: 9 }),
  },
  {
    dimension: "communication",
    scenario: "Your ideal collaboration tool would emphasize:",
    optionAText: "Long-form documents, wikis, and threaded comments. Knowledge that persists and scales.",
    optionBText: "Video calls, screen sharing, and huddles. Real-time presence and instant connection.",
    optionAScores: JSON.stringify({ communication: -10 }),
    optionBScores: JSON.stringify({ communication: 10 }),
  },
  {
    dimension: "communication",
    scenario: "You just had a breakthrough idea at 11 PM. Your co-founder is still awake. What do you do?",
    optionAText: "Write it up in a doc or detailed message. Let them read it fresh in the morning and respond thoughtfully.",
    optionBText: "Call them. The excitement is part of the message, and talking it through together will make it better.",
    optionAScores: JSON.stringify({ communication: -8, pace: -3 }),
    optionBScores: JSON.stringify({ communication: 8, pace: 3 }),
  },
  {
    dimension: "communication",
    scenario: "Your remote team spans 3 time zones. How do you handle important decisions?",
    optionAText: "Async decision docs with clear deadlines for input. Everyone participates equally regardless of timezone.",
    optionBText: "Find an overlap window and do a video call. Important decisions deserve synchronous discussion.",
    optionAScores: JSON.stringify({ communication: -10 }),
    optionBScores: JSON.stringify({ communication: 10 }),
  },
  {
    dimension: "communication",
    scenario: "You're reviewing a teammate's work and have mixed feedback — some praise, some critique. How do you deliver it?",
    optionAText: "Written review with specific comments inline. Clear, referenceable, and they can process at their own pace.",
    optionBText: "Walk through it together on a call. You can calibrate your tone and they can ask questions as you go.",
    optionAScores: JSON.stringify({ communication: -8 }),
    optionBScores: JSON.stringify({ communication: 8 }),
  },
];

async function main() {
  console.log(`\nSeeding ${questions.length} assessment questions...\n`);

  // Clear existing questions (idempotent)
  const deleted = await prisma.assessmentQuestion.deleteMany({});
  if (deleted.count > 0) {
    console.log(`  Cleared ${deleted.count} existing questions`);
  }

  // Count per dimension
  const counts: Record<string, number> = {};

  for (const q of questions) {
    await prisma.assessmentQuestion.create({
      data: {
        dimension: q.dimension,
        scenario: q.scenario,
        optionAText: q.optionAText,
        optionBText: q.optionBText,
        optionAScores: q.optionAScores,
        optionBScores: q.optionBScores,
        isActive: true,
      },
    });
    counts[q.dimension] = (counts[q.dimension] || 0) + 1;
  }

  console.log("  Questions seeded by dimension:");
  for (const [dim, count] of Object.entries(counts)) {
    console.log(`    • ${dim}: ${count}`);
  }
  console.log(`\n✅ Total: ${questions.length} questions seeded!\n`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
SEEDEOF

# Run the seed script
echo ""
echo "Running seed script..."
npx tsx prisma/seed-questions.ts

# Commit and push
git add .
git commit -m "feat: seed 90 working style assessment questions across 6 dimensions"
git push origin main

echo ""
echo "✅ Question bank seeded!"
echo "   90 questions across 6 dimensions (15 each)"
echo "   Each user will get a random 20-question subset"
echo ""
echo "   Next: Step 3 — Assessment page (/assessment)"
