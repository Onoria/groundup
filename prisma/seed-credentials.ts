import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

const CREDENTIALS = [
  // ── Project Management ──
  { name: "Project Management Professional (PMP)", shortName: "PMP", category: "certification", issuer: "PMI", baseXp: 50, unverifiedXp: 15, skillCategory: "operations", skillKeywords: ["project management", "agile", "scrum", "operations"] },
  { name: "Certified Scrum Master (CSM)", shortName: "CSM", category: "certification", issuer: "Scrum Alliance", baseXp: 35, unverifiedXp: 10, skillCategory: "operations", skillKeywords: ["agile", "scrum", "project management"] },
  { name: "PMI Agile Certified Practitioner (PMI-ACP)", shortName: "PMI-ACP", category: "certification", issuer: "PMI", baseXp: 40, unverifiedXp: 12, skillCategory: "operations", skillKeywords: ["agile", "project management"] },
  
  // ── Cloud & DevOps ──
  { name: "AWS Solutions Architect – Associate", shortName: "AWS-SAA", category: "certification", issuer: "Amazon", baseXp: 45, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["aws", "cloud", "devops", "infrastructure"] },
  { name: "AWS Solutions Architect – Professional", shortName: "AWS-SAP", category: "certification", issuer: "Amazon", baseXp: 65, unverifiedXp: 18, skillCategory: "technical", skillKeywords: ["aws", "cloud", "architecture"] },
  { name: "Google Cloud Professional Cloud Architect", shortName: "GCP-PCA", category: "certification", issuer: "Google", baseXp: 55, unverifiedXp: 15, skillCategory: "technical", skillKeywords: ["gcp", "cloud", "architecture"] },
  { name: "Microsoft Azure Solutions Architect", shortName: "AZ-305", category: "certification", issuer: "Microsoft", baseXp: 50, unverifiedXp: 14, skillCategory: "technical", skillKeywords: ["azure", "cloud", "architecture"] },
  { name: "Certified Kubernetes Administrator (CKA)", shortName: "CKA", category: "certification", issuer: "CNCF", baseXp: 45, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["kubernetes", "devops", "infrastructure"] },
  
  // ── Software Engineering ──
  { name: "Meta Front-End Developer Certificate", shortName: "Meta-FE", category: "certification", issuer: "Meta / Coursera", baseXp: 30, unverifiedXp: 10, skillCategory: "technical", skillKeywords: ["frontend", "react", "javascript", "web development"] },
  { name: "Google UX Design Certificate", shortName: "Google-UX", category: "certification", issuer: "Google / Coursera", baseXp: 30, unverifiedXp: 10, skillCategory: "creative", skillKeywords: ["ux", "ui", "design", "user experience"] },
  { name: "GitHub Copilot Certification", shortName: "GH-Copilot", category: "certification", issuer: "GitHub", baseXp: 20, unverifiedXp: 8, skillCategory: "technical", skillKeywords: ["ai", "coding", "developer tools"] },
  
  // ── Data & AI ──
  { name: "Google Professional Data Engineer", shortName: "GCP-DE", category: "certification", issuer: "Google", baseXp: 50, unverifiedXp: 14, skillCategory: "technical", skillKeywords: ["data engineering", "data science", "machine learning"] },
  { name: "AWS Machine Learning Specialty", shortName: "AWS-ML", category: "certification", issuer: "Amazon", baseXp: 55, unverifiedXp: 15, skillCategory: "technical", skillKeywords: ["machine learning", "ai", "data science"] },
  { name: "TensorFlow Developer Certificate", shortName: "TF-Dev", category: "certification", issuer: "Google", baseXp: 40, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["machine learning", "ai", "deep learning", "tensorflow"] },
  
  // ── Business & Finance ──
  { name: "Certified Public Accountant (CPA)", shortName: "CPA", category: "license", issuer: "AICPA", baseXp: 60, unverifiedXp: 18, skillCategory: "business", skillKeywords: ["accounting", "finance", "tax"] },
  { name: "Chartered Financial Analyst (CFA)", shortName: "CFA", category: "certification", issuer: "CFA Institute", baseXp: 65, unverifiedXp: 18, skillCategory: "business", skillKeywords: ["finance", "investing", "financial analysis"] },
  { name: "Certified Financial Planner (CFP)", shortName: "CFP", category: "certification", issuer: "CFP Board", baseXp: 50, unverifiedXp: 15, skillCategory: "business", skillKeywords: ["financial planning", "finance"] },
  { name: "Six Sigma Green Belt", shortName: "SSGB", category: "certification", issuer: "ASQ", baseXp: 35, unverifiedXp: 10, skillCategory: "operations", skillKeywords: ["operations", "process improvement", "quality"] },
  { name: "Six Sigma Black Belt", shortName: "SSBB", category: "certification", issuer: "ASQ", baseXp: 50, unverifiedXp: 15, skillCategory: "operations", skillKeywords: ["operations", "process improvement", "quality", "leadership"] },
  
  // ── Marketing & Sales ──
  { name: "Google Ads Certification", shortName: "GAds", category: "certification", issuer: "Google", baseXp: 25, unverifiedXp: 8, skillCategory: "business", skillKeywords: ["marketing", "advertising", "digital marketing", "google ads"] },
  { name: "HubSpot Inbound Marketing", shortName: "HS-Inbound", category: "certification", issuer: "HubSpot", baseXp: 25, unverifiedXp: 8, skillCategory: "business", skillKeywords: ["marketing", "inbound", "content marketing"] },
  { name: "Salesforce Administrator", shortName: "SF-Admin", category: "certification", issuer: "Salesforce", baseXp: 40, unverifiedXp: 12, skillCategory: "business", skillKeywords: ["salesforce", "crm", "sales"] },
  
  // ── Cybersecurity ──
  { name: "CompTIA Security+", shortName: "Sec+", category: "certification", issuer: "CompTIA", baseXp: 35, unverifiedXp: 10, skillCategory: "technical", skillKeywords: ["security", "cybersecurity", "infosec"] },
  { name: "Certified Information Systems Security Professional (CISSP)", shortName: "CISSP", category: "certification", issuer: "ISC²", baseXp: 65, unverifiedXp: 18, skillCategory: "technical", skillKeywords: ["security", "cybersecurity", "infosec", "architecture"] },
  
  // ── Design ──
  { name: "Adobe Certified Professional", shortName: "ACP", category: "certification", issuer: "Adobe", baseXp: 30, unverifiedXp: 10, skillCategory: "creative", skillKeywords: ["design", "photoshop", "illustrator", "creative"] },
  { name: "Interaction Design Foundation (IxDF) Certification", shortName: "IxDF", category: "certification", issuer: "IxDF", baseXp: 25, unverifiedXp: 8, skillCategory: "creative", skillKeywords: ["ux", "interaction design", "design"] },
  
  // ── Education (Degrees) ──
  { name: "Bachelor's Degree (STEM)", shortName: "BS", category: "education", issuer: null, baseXp: 40, unverifiedXp: 20, skillCategory: "technical", skillKeywords: ["computer science", "engineering", "mathematics", "science"] },
  { name: "Bachelor's Degree (Business)", shortName: "BBA", category: "education", issuer: null, baseXp: 40, unverifiedXp: 20, skillCategory: "business", skillKeywords: ["business", "finance", "marketing", "management"] },
  { name: "Bachelor's Degree (Design/Arts)", shortName: "BFA", category: "education", issuer: null, baseXp: 40, unverifiedXp: 20, skillCategory: "creative", skillKeywords: ["design", "art", "creative", "media"] },
  { name: "Master's Degree (STEM)", shortName: "MS", category: "education", issuer: null, baseXp: 60, unverifiedXp: 30, skillCategory: "technical", skillKeywords: ["computer science", "engineering", "data science", "ai"] },
  { name: "MBA", shortName: "MBA", category: "education", issuer: null, baseXp: 60, unverifiedXp: 30, skillCategory: "business", skillKeywords: ["business", "management", "strategy", "finance", "leadership"] },
  { name: "Master's Degree (Design)", shortName: "MFA", category: "education", issuer: null, baseXp: 55, unverifiedXp: 28, skillCategory: "creative", skillKeywords: ["design", "creative", "art direction"] },
  { name: "PhD", shortName: "PhD", category: "education", issuer: null, baseXp: 80, unverifiedXp: 40, skillCategory: "technical", skillKeywords: ["research", "science", "engineering"] },
  { name: "JD (Law Degree)", shortName: "JD", category: "education", issuer: null, baseXp: 65, unverifiedXp: 32, skillCategory: "business", skillKeywords: ["legal", "law", "compliance", "contracts"] },
  
  // ── Bootcamps ──
  { name: "Coding Bootcamp Graduate", shortName: "Bootcamp", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["web development", "coding", "javascript", "fullstack"] },
  { name: "Data Science Bootcamp Graduate", shortName: "DS-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "technical", skillKeywords: ["data science", "python", "machine learning"] },
  { name: "UX/UI Design Bootcamp Graduate", shortName: "UX-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "creative", skillKeywords: ["ux", "ui", "design", "figma"] },
  { name: "Product Management Bootcamp", shortName: "PM-Boot", category: "bootcamp", issuer: null, baseXp: 25, unverifiedXp: 12, skillCategory: "business", skillKeywords: ["product management", "product", "strategy"] },
];

async function main() {
  console.log("  Seeding credential catalog...");
  
  let created = 0;
  for (const cred of CREDENTIALS) {
    await prisma.credential.upsert({
      where: { name: cred.name },
      update: {
        shortName: cred.shortName,
        category: cred.category,
        issuer: cred.issuer,
        baseXp: cred.baseXp,
        unverifiedXp: cred.unverifiedXp,
        skillCategory: cred.skillCategory,
        skillKeywords: cred.skillKeywords,
      },
      create: cred,
    });
    created++;
  }
  
  console.log(`  ✓ Seeded ${created} credentials`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
