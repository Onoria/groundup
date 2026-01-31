import { auth } from "@clerk/nextjs/server";
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

/**
 * PUT /api/profile/skills
 * Update the current user's skills with proficiency levels
 */
export async function PUT(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await request.json();
    const { skills } = body;

    if (!Array.isArray(skills)) {
      return NextResponse.json(
        { error: "skills must be an array" },
        { status: 400 }
      );
    }

    // Validate each skill entry
    const validProficiencies = ["beginner", "intermediate", "advanced", "expert"];
    for (const skill of skills) {
      if (!skill.name || typeof skill.name !== "string") {
        return NextResponse.json(
          { error: "Each skill must have a name" },
          { status: 400 }
        );
      }
      if (skill.proficiency && !validProficiencies.includes(skill.proficiency)) {
        return NextResponse.json(
          { error: `Invalid proficiency level: ${skill.proficiency}` },
          { status: 400 }
        );
      }
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
    });

    if (!user) {
      return NextResponse.json({ error: "User not found" }, { status: 404 });
    }

    // Upsert each skill in the catalog
    const skillRecords = await Promise.all(
      skills.map(async (s: { name: string; proficiency?: string }) => {
        const category = categorizeSkill(s.name);
        const skill = await prisma.skill.upsert({
          where: { name: s.name },
          update: {},
          create: { name: s.name, category },
        });
        return { skill, proficiency: s.proficiency || "intermediate" };
      })
    );

    // Remove old skills
    await prisma.userSkill.deleteMany({
      where: { userId: user.id },
    });

    // Create new skills with proficiency
    if (skillRecords.length > 0) {
      await prisma.userSkill.createMany({
        data: skillRecords.map(({ skill, proficiency }) => ({
          userId: user.id,
          skillId: skill.id,
          proficiency,
        })),
      });
    }

    // Update timestamp
    await prisma.user.update({
      where: { id: user.id },
      data: { updatedAt: new Date() },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error updating skills:", error);
    return NextResponse.json(
      { error: "Failed to update skills" },
      { status: 500 }
    );
  }
}

/**
 * Categorize a skill name into a category
 * (matches the onboarding route logic)
 */
function categorizeSkill(skillName: string): string {
  const technical = [
    "Frontend Development", "Backend Development", "Mobile Development",
    "DevOps", "Data Science", "Machine Learning", "Cybersecurity", "Database Management",
  ];
  const business = [
    "Sales", "Marketing", "Product Management", "Business Development",
    "Finance", "Operations", "Strategy", "Customer Success",
  ];
  const creative = [
    "UI/UX Design", "Graphic Design", "Content Writing",
    "Video Production", "Brand Strategy", "Social Media",
  ];
  const operations = [
    "Project Management", "Supply Chain", "Quality Assurance",
    "Legal", "HR", "Administration",
  ];

  if (technical.includes(skillName)) return "technical";
  if (business.includes(skillName)) return "business";
  if (creative.includes(skillName)) return "creative";
  if (operations.includes(skillName)) return "operations";
  return "other";
}
