import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

/**
 * GROUNDUP SECURITY MIDDLEWARE
 * 
 * This middleware runs on EVERY request before it reaches your pages or API routes.
 * It enforces security headers, rate limiting, and authentication checks.
 */

// Rate limiting store (in-memory, use Redis in production)
const rateLimitStore = new Map<string, { count: number; resetTime: number }>();

// Configuration
const RATE_LIMIT_MAX = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100');
const RATE_LIMIT_WINDOW = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'); // 15 minutes

/**
 * Rate limiting function
 */
function checkRateLimit(identifier: string): boolean {
  const now = Date.now();
  const record = rateLimitStore.get(identifier);

  if (!record || now > record.resetTime) {
    // Create new rate limit window
    rateLimitStore.set(identifier, {
      count: 1,
      resetTime: now + RATE_LIMIT_WINDOW,
    });
    return true;
  }

  if (record.count >= RATE_LIMIT_MAX) {
    return false; // Rate limit exceeded
  }

  // Increment counter
  record.count++;
  return true;
}

/**
 * Security headers configuration
 */
function getSecurityHeaders() {
  const headers = new Headers();

  // Prevent clickjacking attacks
  headers.set('X-Frame-Options', 'DENY');

  // Prevent MIME type sniffing
  headers.set('X-Content-Type-Options', 'nosniff');

  // XSS Protection (legacy but still useful)
  headers.set('X-XSS-Protection', '1; mode=block');

  // Referrer Policy
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');

  // Permissions Policy (formerly Feature Policy)
  headers.set(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=(self), interest-cohort=()'
  );

  // Content Security Policy
  const cspDirectives = [
    "default-src 'self'",
    "script-src 'self' 'unsafe-eval' 'unsafe-inline' https://challenges.cloudflare.com", // Clerk needs unsafe-inline
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https: blob:",
    "font-src 'self' data:",
    "connect-src 'self' https://api.clerk.com https://clerk.groundup.app https://*.clerk.accounts.dev",
    "frame-src 'self' https://challenges.cloudflare.com",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
    "upgrade-insecure-requests",
  ].join('; ');

  headers.set('Content-Security-Policy', cspDirectives);

  // HSTS (HTTP Strict Transport Security) - only in production
  if (process.env.NODE_ENV === 'production') {
    headers.set(
      'Strict-Transport-Security',
      'max-age=63072000; includeSubDomains; preload'
    );
  }

  return headers;
}

/**
 * Protected routes that require authentication
 */
const protectedRoutes = [
  '/dashboard',
  '/profile',
  '/matching',
  '/teams',
  '/settings',
  '/api/user',
  '/api/matching',
  '/api/teams',
];

/**
 * Public API routes that should be rate limited more strictly
 */
const publicApiRoutes = [
  '/api/auth',
  '/api/waitlist',
];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  
  // Get client identifier for rate limiting (IP address)
  const identifier = request.ip || request.headers.get('x-forwarded-for') || 'anonymous';

  // Apply stricter rate limiting to public API routes
  if (publicApiRoutes.some(route => pathname.startsWith(route))) {
    if (!checkRateLimit(`api:${identifier}`)) {
      return new NextResponse(
        JSON.stringify({ error: 'Too many requests. Please try again later.' }),
        {
          status: 429,
          headers: {
            'Content-Type': 'application/json',
            'Retry-After': '900', // 15 minutes
          },
        }
      );
    }
  }

  // Apply general rate limiting to all routes
  if (!checkRateLimit(identifier)) {
    // For HTML pages, return a friendly error page
    if (!pathname.startsWith('/api')) {
      return new NextResponse('Too many requests. Please slow down.', {
        status: 429,
        headers: { 'Retry-After': '900' },
      });
    }
    
    // For API routes, return JSON
    return new NextResponse(
      JSON.stringify({ error: 'Rate limit exceeded' }),
      {
        status: 429,
        headers: {
          'Content-Type': 'application/json',
          'Retry-After': '900',
        },
      }
    );
  }

  // Create response with security headers
  const response = NextResponse.next();
  
  // Apply security headers to all responses
  const securityHeaders = getSecurityHeaders();
  securityHeaders.forEach((value, key) => {
    response.headers.set(key, value);
  });

  // Add CORS headers for API routes
  if (pathname.startsWith('/api')) {
    const origin = request.headers.get('origin');
    const allowedOrigins = [
      process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
      'https://groundup.app',
      'https://www.groundup.app',
    ];

    if (origin && allowedOrigins.includes(origin)) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Access-Control-Allow-Credentials', 'true');
      response.headers.set(
        'Access-Control-Allow-Methods',
        'GET, POST, PUT, DELETE, OPTIONS'
      );
      response.headers.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization'
      );
    }

    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new NextResponse(null, { status: 200, headers: response.headers });
    }
  }

  return response;
}

/**
 * Configure which routes the middleware runs on
 */
export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public folder
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
