"use client";

import NotificationBell from "@/components/NotificationBell";
import { useParams, useRouter } from "next/navigation";
import { useState, useEffect, useCallback, useRef } from "react";

// ── Field definitions (inline to avoid import issues during build) ──
type FT = "textarea"|"text"|"select"|"url"|"date";
interface FD {
  label:string; type:FT; placeholder?:string; options?:string[];
  secondaryLabel?:string; secondaryType?:FT; secondaryPlaceholder?:string; secondaryOptions?:string[];
  sensitive?:boolean; helpText?:string; longText?:boolean;
}
const CF: Record<number,FD[]> = {
0:[
  {label:"Problem Statement",type:"textarea",placeholder:"Describe the specific problem your business will solve..."},
  {label:"Product / Service Concept",type:"textarea",placeholder:"Describe your product or service and how it works...",longText:true},
  {label:"Unique Value Proposition",type:"textarea",placeholder:"What makes your solution different from existing alternatives?"},
  {label:"Target Audience",type:"textarea",placeholder:"Describe your ideal customer — demographics, behaviors, needs..."},
],
1:[
  {label:"Co-founder Commitment",type:"select",options:["Full-time","Part-time (20+ hrs/wk)","Part-time (10-20 hrs/wk)","Advisory / Minimal","Flexible / TBD"],secondaryLabel:"Details",secondaryType:"textarea",secondaryPlaceholder:"Describe each co-founder's availability..."},
  {label:"Role Assignments",type:"textarea",placeholder:"List each team member and their assigned role..."},
  {label:"Equity Split Discussion",type:"textarea",placeholder:"Document the agreed equity distribution...",sensitive:true},
  {label:"Decision-Making Framework",type:"select",options:["Majority Vote","Unanimous Consent","CEO Has Final Say","Consensus-Based","Domain-Based","Other"],secondaryLabel:"Details",secondaryType:"textarea",secondaryPlaceholder:"Describe how disagreements will be resolved..."},
  {label:"Founders' Agreement",type:"textarea",placeholder:"Outline the key terms of your founders' agreement...",longText:true},
],
2:[
  {label:"Competitor Research",type:"textarea",placeholder:"List your top competitors, their strengths, weaknesses...",longText:true},
  {label:"Customer Research Findings",type:"textarea",placeholder:"Summarize findings from customer interviews or surveys...",longText:true},
  {label:"Market Size Estimate",type:"text",placeholder:"e.g., $2.5B TAM, $500M SAM, $50M SOM",secondaryLabel:"Methodology",secondaryType:"textarea",secondaryPlaceholder:"How did you arrive at these numbers?"},
  {label:"Competitive Advantage",type:"textarea",placeholder:"Describe your sustainable competitive advantage..."},
  {label:"Concept Test Results",type:"url",placeholder:"https://your-landing-page.com",secondaryLabel:"Results & Learnings",secondaryType:"textarea",secondaryPlaceholder:"Describe the test results..."},
],
3:[
  {label:"Executive Summary",type:"textarea",placeholder:"Write a 1-2 page executive summary of your business...",longText:true},
  {label:"Revenue Model",type:"select",options:["Subscription (recurring)","Freemium","Marketplace / Commission","Direct Sales","Advertising","Licensing / Royalties","SaaS","Consulting / Services","E-commerce","Transaction Fees","Hybrid","Other"],secondaryLabel:"Revenue Model Details",secondaryType:"textarea",secondaryPlaceholder:"Describe pricing tiers, unit economics..."},
  {label:"Financial Projections",type:"textarea",placeholder:"Outline 12-18 month projections: revenue, expenses, burn rate...",longText:true,sensitive:true},
  {label:"Marketing & Sales Strategy",type:"textarea",placeholder:"Describe your go-to-market strategy...",longText:true},
  {label:"Milestones & Goals",type:"textarea",placeholder:"List your key milestones with target dates..."},
],
4:[
  {label:"Business Structure",type:"select",options:["LLC","C-Corporation","S-Corporation","General Partnership","Limited Partnership","Sole Proprietorship","B-Corporation","Nonprofit"],secondaryLabel:"Reasoning",secondaryType:"textarea",secondaryPlaceholder:"Why did you choose this structure?"},
  {label:"Business Name",type:"text",placeholder:"Your registered business name",secondaryLabel:"Name Search Results",secondaryType:"textarea",secondaryPlaceholder:"Confirm the name is available..."},
  {label:"Filing Information",type:"text",placeholder:"Filing / confirmation number",secondaryLabel:"Filing Date",secondaryType:"date",sensitive:true},
  {label:"Registered Agent",type:"text",placeholder:"Agent name or service",secondaryLabel:"Agent Address",secondaryType:"text",secondaryPlaceholder:"Street address",sensitive:true},
  {label:"Operating Agreement / Bylaws",type:"textarea",placeholder:"Summarize key provisions...",longText:true},
],
5:[
  {label:"EIN",type:"text",placeholder:"XX-XXXXXXX",sensitive:true},
  {label:"Business Bank Account",type:"text",placeholder:"Bank name",secondaryLabel:"Account Details",secondaryType:"text",secondaryPlaceholder:"Account type and last 4 digits",sensitive:true},
  {label:"Accounting System",type:"select",options:["QuickBooks Online","QuickBooks Desktop","Xero","FreshBooks","Wave (Free)","Zoho Books","Sage","NetSuite","Spreadsheet-based","Other"],secondaryLabel:"Setup Notes",secondaryType:"textarea",secondaryPlaceholder:"Configuration details..."},
  {label:"Financial Separation",type:"textarea",placeholder:"Confirm personal and business finances are separated..."},
  {label:"Budget & Cash Flow Plan",type:"textarea",placeholder:"Outline monthly budget and cash flow projections...",longText:true,sensitive:true},
],
6:[
  {label:"Required Licenses & Permits",type:"textarea",placeholder:"List all required licenses and permits...",longText:true},
  {label:"General Business License",type:"text",placeholder:"License number",secondaryLabel:"Issuing Authority",secondaryType:"text",secondaryPlaceholder:"Which government office?",sensitive:true},
  {label:"Industry-Specific Permits",type:"textarea",placeholder:"List industry-specific permits obtained..."},
  {label:"Business Insurance",type:"text",placeholder:"Insurance provider",secondaryLabel:"Policy Details",secondaryType:"text",secondaryPlaceholder:"Policy type and number",sensitive:true},
  {label:"BOI Report (FinCEN)",type:"date",placeholder:"Filing date",secondaryLabel:"Confirmation",secondaryType:"text",secondaryPlaceholder:"Confirmation number",sensitive:true},
  {label:"State & Local Tax Registration",type:"text",placeholder:"State tax ID",secondaryLabel:"Tax Types",secondaryType:"textarea",secondaryPlaceholder:"Sales tax, income tax, etc.",sensitive:true},
],
7:[
  {label:"MVP / Product Description",type:"textarea",placeholder:"Describe your minimum viable product...",longText:true},
  {label:"Website & Online Presence",type:"url",placeholder:"https://yourbusiness.com",secondaryLabel:"Social Media & Links",secondaryType:"textarea",secondaryPlaceholder:"List social media profiles..."},
  {label:"Marketing Materials",type:"textarea",placeholder:"Describe marketing materials created..."},
  {label:"Sales Channels",type:"textarea",placeholder:"Describe your initial sales channels..."},
  {label:"Launch Plan",type:"textarea",placeholder:"Describe your launch strategy...",secondaryLabel:"Target Launch Date",secondaryType:"date"},
  {label:"Feedback & Iteration Plan",type:"textarea",placeholder:"How will you collect and act on feedback?"},
],
};

// ── Types ────────────────────────────────────
interface MemberUser { id:string; firstName:string|null; lastName:string|null; displayName:string|null; avatarUrl:string|null; email:string; skills:{skill:{name:string};isVerified:boolean}[]; }
interface TeamMember { id:string; userId:string; role:string; title:string|null; equityPercent:number|null; status:string; isAdmin:boolean; joinedAt:string; user:MemberUser; }
interface MilestoneData { id:string; title:string; description:string|null; dueDate:string|null; isCompleted:boolean; }
interface TeamData { id:string; name:string; description:string|null; industry:string|null; businessIdea:string|null; missionStatement:string|null; targetMarket:string|null; businessStage:number; stage:string; trialStartedAt:string|null; trialEndsAt:string|null; members:TeamMember[]; milestones:MilestoneData[]; }
interface MyMembership { id:string; role:string; title:string|null; status:string; isAdmin:boolean; equityPercent:number|null; }
interface ChecklistItem { index:number; label:string; isCompleted:boolean; completedBy:string|null; completedAt:string|null; data:{value?:string;secondary?:string;selection?:string}|null; assignedTo:string|null; dueDate:string|null; }
interface StageChecklist { stageId:number; name:string; icon:string; description:string; totalItems:number; completedItems:number; allComplete:boolean; items:ChecklistItem[]; resources:{label:string;url:string}[]; }
interface ChatMessage { id:string; content:string; createdAt:string; sender:{id:string;firstName:string|null;lastName:string|null;displayName:string|null;avatarUrl:string|null;}; }

const STAGES = [
  {id:0,name:"Ideation",icon:"💡"},{id:1,name:"Team Formation",icon:"👥"},
  {id:2,name:"Market Validation",icon:"🔍"},{id:3,name:"Business Planning",icon:"📋"},
  {id:4,name:"Legal Formation",icon:"⚖️"},{id:5,name:"Financial Setup",icon:"🏦"},
  {id:6,name:"Compliance",icon:"📑"},{id:7,name:"Launch Ready",icon:"🚀"},
];

const TITLES = ["","CEO","CTO","CFO","COO","CPO","Lead Developer","Lead Designer","Project Lead","Foreman","Superintendent","Estimator"];

export default function TeamDetailPage() {
  const params = useParams();
  const router = useRouter();
  const teamId = params.id as string;

  const [team, setTeam] = useState<TeamData|null>(null);
  const [me, setMe] = useState<MyMembership|null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [activeTab, setActiveTab] = useState<"overview"|"chat"|"milestones">("overview");

  // Checklist
  const [checklists, setChecklists] = useState<StageChecklist[]>([]);
  const [expandedStage, setExpandedStage] = useState<number|null>(null);
  const [editingItem, setEditingItem] = useState<string|null>(null); // "stageId-itemIndex"
  const [itemDrafts, setItemDrafts] = useState<Record<string,{value:string;secondary:string;selection:string;assignedTo:string;dueDate:string}>>({});
  const [savingItem, setSavingItem] = useState(false);

  // Business profile
  const [editingBiz, setEditingBiz] = useState(false);
  const [bizIdea, setBizIdea] = useState("");
  const [bizMission, setBizMission] = useState("");
  const [bizMarket, setBizMarket] = useState("");
  const [bizIndustry, setBizIndustry] = useState("");

  // Title/equity
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleInput, setTitleInput] = useState("");
  const [editingEquity, setEditingEquity] = useState<string|null>(null);
  const [equityInput, setEquityInput] = useState("");

  // Milestones
  const [showMsForm, setShowMsForm] = useState(false);
  const [msTitle, setMsTitle] = useState("");
  const [msDesc, setMsDesc] = useState("");
  const [msDue, setMsDue] = useState("");

  // Chat
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [sending, setSending] = useState(false);
  const [currentUserId, setCurrentUserId] = useState("");
  const chatEndRef = useRef<HTMLDivElement>(null);
  const chatPollRef = useRef<ReturnType<typeof setInterval>|null>(null);

  // Actions
  const [actionLoading, setActionLoading] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);

  const flash = (msg:string) => { setToast(msg); setTimeout(()=>setToast(""),4000); };

  // ── Fetch ──────────────────────────────────
  const fetchTeam = useCallback(async()=>{
    try{const r=await fetch(`/api/team/${teamId}`);const d=await r.json();
    if(d.error)setError(d.error);else{setTeam(d.team);setMe(d.myMembership);
    setTitleInput(d.myMembership?.title||"");setBizIdea(d.team.businessIdea||"");
    setBizMission(d.team.missionStatement||"");setBizMarket(d.team.targetMarket||"");
    setBizIndustry(d.team.industry||"");}}catch{setError("Failed to load");}
    finally{setLoading(false);}
  },[teamId]);

  const fetchChecklists = useCallback(async()=>{
    try{const r=await fetch(`/api/team/${teamId}/checklist`);const d=await r.json();
    if(d.stages)setChecklists(d.stages);}catch{}
  },[teamId]);

  const fetchMessages = useCallback(async()=>{
    try{const r=await fetch(`/api/team/${teamId}/messages`);const d=await r.json();
    if(d.messages){setMessages(d.messages);setCurrentUserId(d.currentUserId);}}catch{}
  },[teamId]);

  useEffect(()=>{fetchTeam();},[fetchTeam]);
  useEffect(()=>{if(team){fetchChecklists();setExpandedStage(team.businessStage);}},[team,fetchChecklists]);
  useEffect(()=>{
    if(activeTab==="chat"){fetchMessages();chatPollRef.current=setInterval(fetchMessages,5000);
    return()=>{if(chatPollRef.current)clearInterval(chatPollRef.current);};
    }else{if(chatPollRef.current)clearInterval(chatPollRef.current);}
  },[activeTab,fetchMessages]);
  useEffect(()=>{if(activeTab==="chat")chatEndRef.current?.scrollIntoView({behavior:"smooth"});},[messages,activeTab]);

  // ── Helpers ────────────────────────────────
  const getMemberName=(m:TeamMember)=>m.user.displayName||[m.user.firstName,m.user.lastName].filter(Boolean).join(" ")||"Member";
  const getSenderName=(s:ChatMessage["sender"])=>s.displayName||[s.firstName,s.lastName].filter(Boolean).join(" ")||"Member";
  const getDaysLeft=()=>{if(!team?.trialEndsAt)return null;const d=new Date(team.trialEndsAt).getTime()-Date.now();return Math.max(0,Math.ceil(d/(1000*60*60*24)));};
  const getStageChecklist=(id:number)=>checklists.find(c=>c.stageId===id);
  const getDraftKey=(s:number,i:number)=>`${s}-${i}`;

  // ── Item editing ───────────────────────────
  function startEditItem(stageId:number, item:ChecklistItem) {
    const key = getDraftKey(stageId, item.index);
    setEditingItem(key);
    setItemDrafts(prev=>({...prev,[key]:{
      value: item.data?.value || "",
      secondary: item.data?.secondary || "",
      selection: item.data?.selection || "",
      assignedTo: item.assignedTo || "",
      dueDate: item.dueDate ? item.dueDate.slice(0,10) : "",
    }}));
  }

  function updateDraft(key:string, field:string, val:string) {
    setItemDrafts(prev=>({...prev,[key]:{...prev[key],[field]:val}}));
  }

  async function saveItem(stageId:number, itemIndex:number, alsoComplete:boolean) {
    const key = getDraftKey(stageId, itemIndex);
    const draft = itemDrafts[key];
    if(!draft) return;
    setSavingItem(true);
    try {
      const dataObj:{value?:string;secondary?:string;selection?:string} = {};
      if(draft.value) dataObj.value = draft.value;
      if(draft.secondary) dataObj.secondary = draft.secondary;
      if(draft.selection) dataObj.selection = draft.selection;
      
      const body: Record<string,unknown> = {
        stageId, itemIndex,
        data: dataObj,
        assignedTo: draft.assignedTo || null,
        dueDate: draft.dueDate || null,
      };
      if(alsoComplete) body.isCompleted = true;
      
      await fetch(`/api/team/${teamId}/checklist`,{
        method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify(body),
      });
      setEditingItem(null);
      flash("Saved");
      await fetchChecklists();
    } catch { flash("Failed to save"); }
    setSavingItem(false);
  }

  async function toggleCheck(stageId:number,itemIndex:number,isCompleted:boolean){
    try{
      await fetch(`/api/team/${teamId}/checklist`,{
        method:"PUT",headers:{"Content-Type":"application/json"},
        body:JSON.stringify({stageId,itemIndex,isCompleted}),
      });
      setChecklists(prev=>prev.map(cl=>{
        if(cl.stageId!==stageId)return cl;
        const items=cl.items.map(i=>i.index===itemIndex?{...i,isCompleted}:i);
        const cc=items.filter(i=>i.isCompleted).length;
        return{...cl,items,completedItems:cc,allComplete:cc>=cl.totalItems};
      }));
    }catch{flash("Failed");}
  }

  // ── Standard actions ───────────────────────
  async function advanceStage(){if(!team)return;setActionLoading(true);
    try{const r=await fetch(`/api/team/${teamId}/stage`,{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify({stage:team.businessStage+1})});
    const d=await r.json();if(d.error)flash(d.error);else{flash(`Advanced to ${STAGES[team.businessStage+1]?.name}!`);await fetchTeam();await fetchChecklists();}}
    catch{flash("Failed");}setActionLoading(false);}

  async function saveBusiness(){setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/business`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({businessIdea:bizIdea,missionStatement:bizMission,targetMarket:bizMarket,industry:bizIndustry})});
    setEditingBiz(false);flash("Saved");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function saveTitle(){if(!me)return;setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/members`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({memberId:me.id,title:titleInput})});setEditingTitle(false);flash("Updated");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function saveEquity(mid:string){setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/members`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({memberId:mid,equityPercent:parseFloat(equityInput)||0})});setEditingEquity(null);flash("Updated");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function commitToTeam(){setActionLoading(true);
    try{const r=await fetch(`/api/team/${teamId}/commit`,{method:"POST"});const d=await r.json();
    flash(d.teamAdvanced?"Team is official!":"Committed! Waiting for others.");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function leaveTeam(){setActionLoading(true);try{await fetch(`/api/team/${teamId}/leave`,{method:"POST"});router.push("/team");}catch{flash("Failed");}setActionLoading(false);}

  async function sendMessage(){if(!chatInput.trim()||sending)return;setSending(true);
    try{await fetch(`/api/team/${teamId}/messages`,{method:"POST",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({content:chatInput.trim()})});setChatInput("");await fetchMessages();}catch{flash("Failed");}setSending(false);}

  async function addMilestone(){if(!msTitle.trim())return;setActionLoading(true);
    try{await fetch(`/api/team/${teamId}/milestones`,{method:"POST",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({title:msTitle,description:msDesc,dueDate:msDue||null})});
    setShowMsForm(false);setMsTitle("");setMsDesc("");setMsDue("");flash("Added");await fetchTeam();}catch{flash("Failed");}setActionLoading(false);}

  async function toggleMilestone(id:string,done:boolean){
    try{await fetch(`/api/team/${teamId}/milestones`,{method:"PUT",headers:{"Content-Type":"application/json"},
    body:JSON.stringify({milestoneId:id,isCompleted:done})});await fetchTeam();}catch{}}

  // ── Render item input field ────────────────
  function renderItemInput(stageId:number, item:ChecklistItem) {
    const field = CF[stageId]?.[item.index];
    if(!field) return null;
    const key = getDraftKey(stageId, item.index);
    const draft = itemDrafts[key];
    if(!draft) return null;

    const activeMembers = team?.members.filter(m=>m.status!=="left") || [];

    return (
      <div className="ci-form">
        <div className="ci-form-header">
          <span className="ci-form-label">{field.label}</span>
          {field.sensitive && <span className="ci-sensitive-badge">🔒 Sensitive</span>}
        </div>
        {field.helpText && <p className="ci-help">{field.helpText}</p>}

        {/* Primary field */}
        {field.type === "select" && field.options ? (
          <select className="ci-select" value={draft.selection} onChange={e=>updateDraft(key,"selection",e.target.value)}>
            <option value="">— Select —</option>
            {field.options.map(o=><option key={o} value={o}>{o}</option>)}
          </select>
        ) : field.type === "textarea" ? (
          <textarea className={`ci-textarea ${field.longText?"ci-textarea-lg":""}`} value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} placeholder={field.placeholder} rows={field.longText?8:4} />
        ) : field.type === "url" ? (
          <input className="ci-input" type="url" value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} placeholder={field.placeholder} />
        ) : field.type === "date" ? (
          <input className="ci-input" type="date" value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} />
        ) : (
          <input className="ci-input" type="text" value={draft.value} onChange={e=>updateDraft(key,"value",e.target.value)} placeholder={field.placeholder} />
        )}

        {/* Secondary field */}
        {field.secondaryLabel && (
          <div className="ci-secondary">
            <label className="ci-secondary-label">{field.secondaryLabel}</label>
            {field.secondaryType === "textarea" ? (
              <textarea className="ci-textarea" value={draft.secondary} onChange={e=>updateDraft(key,"secondary",e.target.value)} placeholder={field.secondaryPlaceholder} rows={3} />
            ) : field.secondaryType === "date" ? (
              <input className="ci-input" type="date" value={draft.secondary} onChange={e=>updateDraft(key,"secondary",e.target.value)} />
            ) : (
              <input className="ci-input" type="text" value={draft.secondary} onChange={e=>updateDraft(key,"secondary",e.target.value)} placeholder={field.secondaryPlaceholder} />
            )}
          </div>
        )}

        {/* Assignment and Due Date */}
        <div className="ci-meta-row">
          <div className="ci-meta-field">
            <label className="ci-meta-label">Assign to</label>
            <select className="ci-select-sm" value={draft.assignedTo} onChange={e=>updateDraft(key,"assignedTo",e.target.value)}>
              <option value="">— Unassigned —</option>
              {activeMembers.map(m=><option key={m.userId} value={m.userId}>{getMemberName(m)}</option>)}
            </select>
          </div>
          <div className="ci-meta-field">
            <label className="ci-meta-label">Due date</label>
            <input className="ci-input-sm" type="date" value={draft.dueDate} onChange={e=>updateDraft(key,"dueDate",e.target.value)} />
          </div>
        </div>

        {/* Actions */}
        <div className="ci-actions">
          <button className="team-btn-sm team-btn-save" onClick={()=>saveItem(stageId,item.index,false)} disabled={savingItem}>Save Draft</button>
          <button className="team-btn-sm ci-btn-complete" onClick={()=>saveItem(stageId,item.index,true)} disabled={savingItem}>Save & Complete ✓</button>
          <button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingItem(null)}>Cancel</button>
        </div>
      </div>
    );
  }

  // ── Render item display (read mode) ────────
  function renderItemDisplay(stageId:number, item:ChecklistItem) {
    const field = CF[stageId]?.[item.index];
    if(!field || !item.data) return null;
    const d = item.data;
    const parts:React.ReactNode[] = [];
    if(d.selection) parts.push(<div key="s" className="ci-display-selection">{d.selection}</div>);
    if(d.value) parts.push(<div key="v" className="ci-display-value">{d.value}</div>);
    if(d.secondary && field.secondaryLabel) parts.push(<div key="x" className="ci-display-secondary"><strong>{field.secondaryLabel}:</strong> {d.secondary}</div>);
    return parts.length > 0 ? <div className="ci-display">{parts}</div> : null;
  }

  // ── Main render ────────────────────────────
  if(loading)return<div className="team-container"><div className="team-loading">Loading team...</div></div>;
  if(error||!team||!me)return<div className="team-container"><div className="team-error">{error||"Team not found"}</div></div>;

  const daysLeft = getDaysLeft();
  const activeMembers = team.members.filter(m=>m.status!=="left");
  const completedMs = team.milestones.filter(m=>m.isCompleted).length;
  const currentChecklist = getStageChecklist(team.businessStage);
  const canAdvance = currentChecklist?.allComplete && team.businessStage < 7;

  return (
    <div className="team-container">
      <header className="team-header"><div className="team-header-content">
        <a href="/team" className="team-back-link">← My Teams</a>
        <div style={{display:"flex",alignItems:"center",gap:"16px"}}><NotificationBell /><h1 className="team-logo">GroundUp</h1></div>
      </div></header>

      {toast && <div className="team-toast">{toast}</div>}

      <main className="team-main">
        {/* Team header */}
        <section className="team-info-section">
          <div className="team-info-top">
            <div>
              <h2 className="team-detail-name">{team.name}</h2>
              {team.industry && <span className="team-detail-industry">{team.industry}</span>}
              {team.description && <p className="team-detail-desc">{team.description}</p>}
            </div>
            <span className={`team-stage-badge team-stage-${team.stage}`}>
              {team.stage==="trial"?"Trial Period":team.stage==="committed"?"Committed":team.stage==="incorporated"?"Incorporated":team.stage==="dissolved"?"Dissolved":"Forming"}
            </span>
          </div>
          {team.stage==="trial" && daysLeft!==null && (
            <div className="team-trial-bar"><div className="team-trial-info"><span className="team-trial-label">Trial Period</span><span className="team-trial-days">{daysLeft>0?`${daysLeft} days remaining`:"Trial ended"}</span></div>
            <div className="team-trial-track"><div className="team-trial-fill" style={{width:`${Math.min(100,((21-(daysLeft||0))/21)*100)}%`}}/></div></div>
          )}
        </section>

        {/* Tabs */}
        <div className="team-tabs">
          <button className={`team-tab ${activeTab==="overview"?"team-tab-active":""}`} onClick={()=>setActiveTab("overview")}>Overview</button>
          <button className={`team-tab ${activeTab==="chat"?"team-tab-active":""}`} onClick={()=>setActiveTab("chat")}>Team Chat</button>
          <button className={`team-tab ${activeTab==="milestones"?"team-tab-active":""}`} onClick={()=>setActiveTab("milestones")}>
            Milestones {team.milestones.length>0 && <span className="team-tab-count">{completedMs}/{team.milestones.length}</span>}
          </button>
        </div>

        {/* ═══ OVERVIEW TAB ═══ */}
        {activeTab==="overview" && (<>
          {/* Formation Journey */}
          <section className="team-section">
            <div className="team-section-header">
              <h3 className="team-section-title">Formation Journey</h3>
              <div style={{display:"flex",gap:"12px",alignItems:"center"}}>
                <a href={`/team/${teamId}/export`} className="team-res-link">Export PDF →</a>
                <a href="/resources" className="team-res-link">Resources →</a>
              </div>
            </div>

            {/* Timeline */}
            <div className="fj-timeline">
              {STAGES.map(s=>{
                const isComplete=s.id<team.businessStage;
                const isCurrent=s.id===team.businessStage;
                const cl=getStageChecklist(s.id);
                const progress=cl?`${cl.completedItems}/${cl.totalItems}`:"";
                return(
                  <div key={s.id} className={`fj-stage ${isComplete?"fj-complete":""} ${isCurrent?"fj-current":""} ${s.id>team.businessStage?"fj-future":""}`}
                    onClick={()=>{if(isComplete||isCurrent)setExpandedStage(expandedStage===s.id?null:s.id);}}
                    style={{cursor:isComplete||isCurrent?"pointer":"default"}}>
                    <div className="fj-dot">{isComplete?<span>✓</span>:<span>{s.icon}</span>}</div>
                    <div className="fj-label">{s.name}</div>
                    {isCurrent && <div className="fj-progress-badge">{progress}</div>}
                    {isComplete && <div className="fj-done-badge">Done</div>}
                    {s.id<7 && <div className={`fj-line ${isComplete?"fj-line-done":""}`}/>}
                  </div>
                );
              })}
            </div>

            {/* Expanded checklist with data entry */}
            {expandedStage!==null && (()=>{
              const cl=getStageChecklist(expandedStage);
              if(!cl) return null;
              const isCurrentStage=expandedStage===team.businessStage;
              const isPastStage=expandedStage<team.businessStage;

              return(
                <div className="fj-checklist-panel">
                  <div className="fj-checklist-header">
                    <div><span className="fj-checklist-icon">{cl.icon}</span><span className="fj-checklist-name">{cl.name}</span>
                    {isPastStage && <span className="fj-checklist-complete-badge">Completed ✓</span>}</div>
                    <span className={`fj-checklist-counter ${cl.allComplete?"fj-counter-done":""}`}>{cl.completedItems}/{cl.totalItems}</span>
                  </div>
                  <p className="fj-checklist-desc">{cl.description}</p>
                  <div className="fj-progress-bar"><div className="fj-progress-fill" style={{width:`${cl.totalItems>0?(cl.completedItems/cl.totalItems)*100:0}%`}}/></div>

                  <div className="fj-items">
                    {cl.items.map(item=>{
                      const key=getDraftKey(cl.stageId,item.index);
                      const isEditing=editingItem===key;
                      const field=CF[cl.stageId]?.[item.index];
                      const memberLookup = team.members.reduce((acc,m)=>{acc[m.userId]=getMemberName(m);return acc;},{} as Record<string,string>);

                      return(
                        <div key={item.index} className={`fj-item-rich ${item.isCompleted?"fj-item-done":""}`}>
                          <div className="fj-item-top">
                            <input type="checkbox" className="fj-item-check" checked={item.isCompleted}
                              disabled={!isCurrentStage && !isPastStage}
                              onChange={e=>toggleCheck(cl.stageId,item.index,e.target.checked)} />
                            <div className="fj-item-info">
                              <span className="fj-item-label">{field?.label || item.label}</span>
                              <div className="fj-item-badges">
                                {item.assignedTo && <span className="fj-item-assigned">{memberLookup[item.assignedTo]||"Assigned"}</span>}
                                {item.dueDate && <span className="fj-item-due">Due: {new Date(item.dueDate).toLocaleDateString()}</span>}
                                {item.completedAt && <span className="fj-item-date">Done {new Date(item.completedAt).toLocaleDateString()}</span>}
                              </div>
                            </div>
                            {(isCurrentStage||isPastStage) && !isEditing && (
                              <button className="fj-item-edit-btn" onClick={()=>startEditItem(cl.stageId,item)}>
                                {item.data ? "Edit" : "Add Details"}
                              </button>
                            )}
                          </div>

                          {/* Display saved data */}
                          {!isEditing && item.data && renderItemDisplay(cl.stageId,item)}

                          {/* Edit form */}
                          {isEditing && renderItemInput(cl.stageId,item)}
                        </div>
                      );
                    })}
                  </div>

                  {/* Resources */}
                  {cl.resources && cl.resources.length>0 && (
                    <div className="fj-resources"><span className="fj-resources-label">Resources:</span>
                    {cl.resources.map((r,i)=><a key={i} href={r.url} target="_blank" rel="noopener noreferrer" className="fj-resource-link">{r.label} ↗</a>)}</div>
                  )}

                  {/* Advance */}
                  {isCurrentStage && team.businessStage<7 && (
                    <div className="fj-advance-section">
                      {canAdvance ? (
                        <button className="fj-advance-btn fj-advance-ready" onClick={advanceStage} disabled={actionLoading}>
                          {actionLoading?"Advancing...":`Advance to ${STAGES[team.businessStage+1].name} →`}
                        </button>
                      ):(
                        <div className="fj-advance-locked"><span className="fj-lock-icon">🔒</span><span>Complete all {cl.totalItems} items to unlock the next stage</span></div>
                      )}
                    </div>
                  )}
                  {isCurrentStage && team.businessStage===7 && cl.allComplete && (
                    <div className="fj-advance-section">
                      <div className="fj-launch-msg">🎉 All formation stages complete — your business is launch ready!
                        <a href={`/team/${teamId}/export`} className="fj-export-link">Export Formation Report →</a>
                      </div>
                    </div>
                  )}
                </div>
              );
            })()}
          </section>

          {/* Business Profile */}
          <section className="team-section">
            <div className="team-section-header"><h3 className="team-section-title">Business Profile</h3>
            {!editingBiz && <button className="team-edit-link" onClick={()=>setEditingBiz(true)}>Edit</button>}</div>
            {editingBiz?(
              <div className="biz-form">
                <div className="biz-field"><label className="biz-label">Business Idea</label><textarea className="biz-textarea" value={bizIdea} onChange={e=>setBizIdea(e.target.value)} placeholder="What's the big idea?" rows={3}/></div>
                <div className="biz-field"><label className="biz-label">Mission Statement</label><textarea className="biz-textarea" value={bizMission} onChange={e=>setBizMission(e.target.value)} placeholder="What's your mission?" rows={2}/></div>
                <div className="biz-row">
                  <div className="biz-field"><label className="biz-label">Target Market</label><input className="biz-input" value={bizMarket} onChange={e=>setBizMarket(e.target.value)} placeholder="Who are your customers?"/></div>
                  <div className="biz-field"><label className="biz-label">Industry</label><input className="biz-input" value={bizIndustry} onChange={e=>setBizIndustry(e.target.value)} placeholder="e.g. SaaS, Construction"/></div>
                </div>
                <div className="biz-actions"><button className="team-btn-sm team-btn-save" onClick={saveBusiness} disabled={actionLoading}>Save</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingBiz(false)}>Cancel</button></div>
              </div>
            ):(
              <div className="biz-display">
                {team.businessIdea?(<>
                  <div className="biz-item"><span className="biz-item-label">Business Idea</span><p className="biz-item-value">{team.businessIdea}</p></div>
                  {team.missionStatement && <div className="biz-item"><span className="biz-item-label">Mission</span><p className="biz-item-value">{team.missionStatement}</p></div>}
                  <div className="biz-row-display">
                    {team.targetMarket && <div className="biz-item"><span className="biz-item-label">Target Market</span><p className="biz-item-value">{team.targetMarket}</p></div>}
                    {team.industry && <div className="biz-item"><span className="biz-item-label">Industry</span><p className="biz-item-value">{team.industry}</p></div>}
                  </div>
                </>):(<p className="biz-empty">No business profile yet. Click Edit to describe your concept.</p>)}
              </div>
            )}
          </section>

          {/* Members */}
          <section className="team-section">
            <h3 className="team-section-title">Team Members <span className="team-section-count">{activeMembers.length}</span></h3>
            <div className="team-members-grid">
              {activeMembers.map(member=>{const isMeCheck=member.id===me.id;const name=getMemberName(member);
                return(<div key={member.id} className={`team-member-card ${isMeCheck?"team-member-me":""}`}>
                  <div className="team-member-top">
                    <div className="team-member-avatar">{member.user.avatarUrl?<img src={member.user.avatarUrl} alt={name}/>:<span>{(member.user.firstName?.[0]||"?").toUpperCase()}</span>}</div>
                    <div className="team-member-info"><span className="team-member-name">{name}{isMeCheck && <span className="team-member-you">(you)</span>}</span><span className="team-member-role">{member.role==="founder"?"Founder":member.role==="cofounder"?"Co-founder":"Advisor"}</span></div>
                    <span className={`team-member-status team-member-status-${member.status}`}>{member.status==="committed"?"Committed":member.status==="trial"?"In Trial":member.status}</span>
                  </div>
                  <div className="team-member-detail"><span className="team-member-detail-label">Title</span>
                    {isMeCheck && editingTitle?(<div className="team-inline-edit"><select value={titleInput} onChange={e=>setTitleInput(e.target.value)} className="team-select">{TITLES.map(t=><option key={t} value={t}>{t||"— None —"}</option>)}</select><button className="team-btn-sm team-btn-save" onClick={saveTitle} disabled={actionLoading}>Save</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingTitle(false)}>Cancel</button></div>
                    ):(<span className="team-member-detail-value">{member.title||"Not set"}{isMeCheck && <button className="team-edit-link" onClick={()=>{setEditingTitle(true);setTitleInput(member.title||"");}}>Edit</button>}</span>)}
                  </div>
                  <div className="team-member-detail"><span className="team-member-detail-label">Equity</span>
                    {me.isAdmin && editingEquity===member.id?(<div className="team-inline-edit"><input type="number" className="team-input-sm" value={equityInput} onChange={e=>setEquityInput(e.target.value)} min="0" max="100" step="0.5" placeholder="%"/><span className="team-equity-pct">%</span><button className="team-btn-sm team-btn-save" onClick={()=>saveEquity(member.id)} disabled={actionLoading}>Save</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setEditingEquity(null)}>Cancel</button></div>
                    ):(<span className="team-member-detail-value">{member.equityPercent!==null?`${member.equityPercent}%`:"Not set"}{me.isAdmin && <button className="team-edit-link" onClick={()=>{setEditingEquity(member.id);setEquityInput(String(member.equityPercent??""));}}>Edit</button>}</span>)}
                  </div>
                  {member.user.skills.length>0 && <div className="team-member-skills">{member.user.skills.slice(0,3).map((s,i)=><span key={i} className="team-skill-tag">{s.skill.name}{s.isVerified && <span className="team-skill-verified">✓</span>}</span>)}</div>}
                </div>);
              })}
            </div>
          </section>

          {/* Commitment */}
          {team.stage==="trial" && me.status!=="left" && (
            <section className="team-section team-commit-section">
              <h3 className="team-section-title">Team Commitment</h3>
              <p className="team-commit-desc">During the 21-day trial, work together and decide if this is the right team.</p>
              <div className="team-commit-statuses">{activeMembers.map(m=>(
                <div key={m.id} className="team-commit-row"><span className="team-commit-name">{getMemberName(m)}{m.id===me.id?" (you)":""}</span>
                <span className={`team-commit-status ${m.status==="committed"?"team-committed-yes":""}`}>{m.status==="committed"?"Committed":"Not yet"}</span></div>
              ))}</div>
              <div className="team-commit-actions">
                {me.status!=="committed"?(<button className="team-commit-btn" onClick={commitToTeam} disabled={actionLoading}>{actionLoading?"...":"Commit to This Team"}</button>):(<span className="team-committed-badge">You have committed ✓</span>)}
                {!confirmLeave?(<button className="team-leave-btn" onClick={()=>setConfirmLeave(true)}>Leave Team</button>
                ):(<div className="team-leave-confirm"><span>Are you sure?</span><button className="team-leave-btn team-leave-confirm-btn" onClick={leaveTeam} disabled={actionLoading}>Yes, Leave</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setConfirmLeave(false)}>Cancel</button></div>)}
              </div>
            </section>
          )}
          {team.stage==="committed" && (<section className="team-section team-committed-section"><div className="team-committed-msg"><span className="team-committed-icon">✅</span><div><p className="team-committed-title">Team is Official!</p><p className="team-committed-sub">All members committed. Time to execute.</p></div></div></section>)}
        </>)}

        {/* ═══ CHAT TAB ═══ */}
        {activeTab==="chat" && (
          <section className="team-section chat-section">
            <div className="chat-messages">
              {messages.length===0 && <div className="chat-empty"><span className="chat-empty-icon">💬</span><p>No messages yet.</p></div>}
              {messages.map((msg,i)=>{const isMe=msg.sender.id===currentUserId;const showAvatar=i===0||messages[i-1].sender.id!==msg.sender.id;
                return(<div key={msg.id} className={`chat-msg ${isMe?"chat-msg-me":"chat-msg-them"}`}>
                  {!isMe&&showAvatar&&<div className="chat-msg-avatar">{msg.sender.avatarUrl?<img src={msg.sender.avatarUrl} alt=""/>:<span>{(msg.sender.firstName?.[0]||"?").toUpperCase()}</span>}</div>}
                  <div className="chat-msg-body">{!isMe&&showAvatar&&<span className="chat-msg-name">{getSenderName(msg.sender)}</span>}<div className="chat-bubble">{msg.content}</div><span className="chat-msg-time">{new Date(msg.createdAt).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"})}</span></div>
                </div>);})}
              <div ref={chatEndRef}/>
            </div>
            <div className="chat-input-bar"><input className="chat-input" value={chatInput} onChange={e=>setChatInput(e.target.value)} onKeyDown={e=>e.key==="Enter"&&!e.shiftKey&&sendMessage()} placeholder="Type a message..." maxLength={2000}/><button className="chat-send-btn" onClick={sendMessage} disabled={sending||!chatInput.trim()}>{sending?"...":"Send"}</button></div>
          </section>
        )}

        {/* ═══ MILESTONES TAB ═══ */}
        {activeTab==="milestones" && (
          <section className="team-section">
            <div className="team-section-header"><h3 className="team-section-title">Team Milestones</h3>{!showMsForm&&<button className="team-add-btn" onClick={()=>setShowMsForm(true)}>+ Add</button>}</div>
            {showMsForm&&(<div className="team-ms-form"><input className="team-ms-input" placeholder="Milestone title..." value={msTitle} onChange={e=>setMsTitle(e.target.value)}/><input className="team-ms-input" placeholder="Description (optional)" value={msDesc} onChange={e=>setMsDesc(e.target.value)}/><input className="team-ms-input" type="date" value={msDue} onChange={e=>setMsDue(e.target.value)}/><div className="team-ms-form-actions"><button className="team-btn-sm team-btn-save" onClick={addMilestone} disabled={actionLoading||!msTitle.trim()}>Add</button><button className="team-btn-sm team-btn-cancel" onClick={()=>setShowMsForm(false)}>Cancel</button></div></div>)}
            {team.milestones.length===0&&!showMsForm&&<p className="team-empty-hint">No milestones yet.</p>}
            <div className="team-ms-list">{team.milestones.map(ms=>(
              <div key={ms.id} className={`team-ms-item ${ms.isCompleted?"team-ms-done":""}`}><button className="team-ms-check" onClick={()=>toggleMilestone(ms.id,!ms.isCompleted)}>{ms.isCompleted?"✓":""}</button><div className="team-ms-content"><span className="team-ms-title">{ms.title}</span>{ms.description&&<span className="team-ms-desc">{ms.description}</span>}</div>{ms.dueDate&&<span className="team-ms-due">{new Date(ms.dueDate).toLocaleDateString()}</span>}</div>
            ))}</div>
          </section>
        )}
      </main>
    </div>
  );
}
