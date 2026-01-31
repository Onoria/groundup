/**
 * GROUNDUP PRISMA CLIENT
 * 
 * Singleton instance of Prisma Client for database access
 * Includes connection pooling and proper error handling
 */

import { PrismaClient } from '@prisma/client';

// ==========================================
// TYPE EXTENSIONS
// ==========================================

// Extend Prisma Client with custom methods if needed
const prismaClientSingleton = () => {
  return new PrismaClient({
    log:
      process.env.NODE_ENV === 'development'
        ? ['query', 'error', 'warn']
        : ['error'],
    errorFormat: 'pretty',
  });
};

// ==========================================
// SINGLETON PATTERN
// ==========================================

declare global {
  var prismaGlobal: undefined | ReturnType<typeof prismaClientSingleton>;
}

export const prisma = globalThis.prismaGlobal ?? prismaClientSingleton();

if (process.env.NODE_ENV !== 'production') {
  globalThis.prismaGlobal = prisma;
}

// ==========================================
// GRACEFUL SHUTDOWN
// ==========================================

// Handle cleanup on exit
if (process.env.NODE_ENV === 'production') {
  process.on('beforeExit', async () => {
    await prisma.$disconnect();
  });
}

// ==========================================
// HELPER FUNCTIONS
// ==========================================

/**
 * Execute a database transaction with retry logic
 */
export async function executeTransaction<T>(
  operation: (tx: PrismaClient) => Promise<T>,
  maxRetries: number = 3
): Promise<T> {
  let lastError: Error | null = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await prisma.$transaction(async (tx) => {
        return await operation(tx as PrismaClient);
      });
    } catch (error) {
      lastError = error as Error;
      
      // Only retry on specific errors (connection issues, deadlocks)
      if (
        !error ||
        typeof error !== 'object' ||
        !('code' in error) ||
        !['P2034', 'P2024'].includes((error as any).code)
      ) {
        throw error;
      }

      // Wait before retrying (exponential backoff)
      if (attempt < maxRetries) {
        await new Promise((resolve) =>
          setTimeout(resolve, Math.pow(2, attempt) * 100)
        );
      }
    }
  }

  throw lastError || new Error('Transaction failed after retries');
}

/**
 * Health check for database connection
 */
export async function checkDatabaseHealth(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return true;
  } catch (error) {
    console.error('Database health check failed:', error);
    return false;
  }
}
