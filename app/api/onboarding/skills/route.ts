import { auth } from '@clerk/nextjs/server';
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function POST(request: Request) {
  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const body = await request.json();
    const { skills } = body;

    if (!Array.isArray(skills) || skills.length === 0) {
      return NextResponse.json({ error: 'At least one skill is required' }, { status: 400 });
    }

    const user = await prisma.user.findUnique({
      where: { clerkId: userId },
    });

    if (!user) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }

    const skillRecords = await Promise.all(
      skills.map(async (skillName: string) => {
        const category = categorizeSkill(skillName);
        return prisma.skill.upsert({
          where: { name: skillName },
          update: {},
          create: { name: skillName, category },
        });
      })
    );

    await prisma.userSkill.deleteMany({
      where: { userId: user.id },
    });

    await prisma.userSkill.createMany({
      data: skillRecords.map((skill) => ({
        userId: user.id,
        skillId: skill.id,
        proficiencyLevel: 'intermediate',
      })),
    });

    await prisma.user.update({
      where: { id: user.id },
      data: { onboardingStep: 'preferences', updatedAt: new Date() },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Error saving skills:', error);
    return NextResponse.json({ error: 'Failed to save skills' }, { status: 500 });
  }
}

function categorizeSkill(skillName: string): string {
  const technical = ['Frontend Development', 'Backend Development', 'Mobile Development', 'DevOps', 'Data Science', 'Machine Learning', 'Cybersecurity', 'Database Management'];
  const business = ['Sales', 'Marketing', 'Product Management', 'Business Development', 'Finance', 'Operations', 'Strategy', 'Customer Success'];
  const creative = ['UI/UX Design', 'Graphic Design', 'Content Writing', 'Video Production', 'Brand Strategy', 'Social Media'];
  const operations = ['Project Management', 'Supply Chain', 'Quality Assurance', 'Legal', 'HR', 'Administration'];

  if (technical.includes(skillName)) return 'technical';
  if (business.includes(skillName)) return 'business';
  if (creative.includes(skillName)) return 'creative';
  if (operations.includes(skillName)) return 'operations';
  return 'other';
}
