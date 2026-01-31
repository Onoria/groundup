/**
 * GROUNDUP ENCRYPTION UTILITIES
 * 
 * Functions for encrypting/decrypting sensitive user data
 * Uses AES-256-GCM for encryption
 */

import { createCipheriv, createDecipheriv, randomBytes, scrypt } from 'crypto';
import { promisify } from 'util';

const scryptAsync = promisify(scrypt);

// ==========================================
// CONFIGURATION
// ==========================================

const ALGORITHM = 'aes-256-gcm';
const KEY_LENGTH = 32; // 256 bits
const IV_LENGTH = 16; // 128 bits
const SALT_LENGTH = 32;
const TAG_LENGTH = 16;
const TAG_POSITION = SALT_LENGTH + IV_LENGTH;
const ENCRYPTED_POSITION = TAG_POSITION + TAG_LENGTH;

/**
 * Get encryption key from environment variable
 */
function getEncryptionKey(): string {
  const key = process.env.ENCRYPTION_KEY;
  if (!key) {
    throw new Error('ENCRYPTION_KEY environment variable is not set');
  }
  if (key.length < 32) {
    throw new Error('ENCRYPTION_KEY must be at least 32 characters');
  }
  return key;
}

// ==========================================
// ENCRYPTION FUNCTIONS
// ==========================================

/**
 * Encrypt a string value
 * 
 * @param plaintext - The value to encrypt
 * @returns Base64-encoded encrypted string
 */
export async function encrypt(plaintext: string): Promise<string> {
  try {
    const masterKey = getEncryptionKey();
    
    // Generate random salt for key derivation
    const salt = randomBytes(SALT_LENGTH);
    
    // Derive encryption key from master key + salt
    const key = (await scryptAsync(masterKey, salt, KEY_LENGTH)) as Buffer;
    
    // Generate random IV
    const iv = randomBytes(IV_LENGTH);
    
    // Create cipher
    const cipher = createCipheriv(ALGORITHM, key, iv);
    
    // Encrypt the data
    const encrypted = Buffer.concat([
      cipher.update(plaintext, 'utf8'),
      cipher.final(),
    ]);
    
    // Get authentication tag
    const tag = cipher.getAuthTag();
    
    // Combine salt + iv + tag + encrypted data
    const result = Buffer.concat([salt, iv, tag, encrypted]);
    
    // Return as base64
    return result.toString('base64');
  } catch (error) {
    console.error('Encryption error:', error);
    throw new Error('Failed to encrypt data');
  }
}

/**
 * Decrypt a string value
 * 
 * @param encryptedData - Base64-encoded encrypted string
 * @returns Decrypted plaintext
 */
export async function decrypt(encryptedData: string): Promise<string> {
  try {
    const masterKey = getEncryptionKey();
    
    // Decode from base64
    const data = Buffer.from(encryptedData, 'base64');
    
    // Extract components
    const salt = data.subarray(0, SALT_LENGTH);
    const iv = data.subarray(SALT_LENGTH, TAG_POSITION);
    const tag = data.subarray(TAG_POSITION, ENCRYPTED_POSITION);
    const encrypted = data.subarray(ENCRYPTED_POSITION);
    
    // Derive decryption key
    const key = (await scryptAsync(masterKey, salt, KEY_LENGTH)) as Buffer;
    
    // Create decipher
    const decipher = createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(tag);
    
    // Decrypt the data
    const decrypted = Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]);
    
    return decrypted.toString('utf8');
  } catch (error) {
    console.error('Decryption error:', error);
    throw new Error('Failed to decrypt data');
  }
}

// ==========================================
// FIELD-LEVEL ENCRYPTION
// ==========================================

/**
 * Encrypt an object's sensitive fields
 * 
 * @param data - Object containing data
 * @param sensitiveFields - Array of field names to encrypt
 * @returns Object with encrypted fields
 */
export async function encryptFields<T extends Record<string, any>>(
  data: T,
  sensitiveFields: (keyof T)[]
): Promise<T> {
  const result = { ...data };
  
  for (const field of sensitiveFields) {
    if (result[field] && typeof result[field] === 'string') {
      result[field] = await encrypt(result[field] as string) as any;
    }
  }
  
  return result;
}

/**
 * Decrypt an object's encrypted fields
 * 
 * @param data - Object with encrypted fields
 * @param encryptedFields - Array of field names to decrypt
 * @returns Object with decrypted fields
 */
export async function decryptFields<T extends Record<string, any>>(
  data: T,
  encryptedFields: (keyof T)[]
): Promise<T> {
  const result = { ...data };
  
  for (const field of encryptedFields) {
    if (result[field] && typeof result[field] === 'string') {
      try {
        result[field] = await decrypt(result[field] as string) as any;
      } catch (error) {
        console.error(`Failed to decrypt field ${String(field)}:`, error);
        // Don't throw - just leave encrypted
      }
    }
  }
  
  return result;
}

// ==========================================
// HASH FUNCTIONS (for passwords, tokens)
// ==========================================

/**
 * Hash a value using SHA-256
 * Use this for tokens, not passwords (use bcrypt for passwords)
 */
export function hash(value: string): string {
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(value).digest('hex');
}

/**
 * Generate a secure random token
 */
export function generateToken(length: number = 32): string {
  return randomBytes(length).toString('hex');
}

// ==========================================
// EXAMPLE USAGE
// ==========================================

/**
 * Example: Encrypting user profile data before storing in database
 */
export async function encryptUserProfile(profile: {
  email: string;
  firstName?: string;
  lastName?: string;
  ssn?: string; // Very sensitive!
  phoneNumber?: string;
}) {
  return encryptFields(profile, ['ssn', 'phoneNumber']);
}

/**
 * Example: Decrypting user profile data after retrieving from database
 */
export async function decryptUserProfile(encryptedProfile: {
  email: string;
  firstName?: string;
  lastName?: string;
  ssn?: string;
  phoneNumber?: string;
}) {
  return decryptFields(encryptedProfile, ['ssn', 'phoneNumber']);
}

/**
 * Example: Encrypting message content
 */
export async function encryptMessage(content: string): Promise<string> {
  return encrypt(content);
}

/**
 * Example: Decrypting message content
 */
export async function decryptMessage(encryptedContent: string): Promise<string> {
  return decrypt(encryptedContent);
}

// ==========================================
// HELPERS FOR COMMON USE CASES
// ==========================================

/**
 * Encrypt sensitive verification data
 */
export async function encryptVerificationData(data: Record<string, any>): Promise<string> {
  return encrypt(JSON.stringify(data));
}

/**
 * Decrypt verification data
 */
export async function decryptVerificationData(encryptedData: string): Promise<Record<string, any>> {
  const decrypted = await decrypt(encryptedData);
  return JSON.parse(decrypted);
}

/**
 * Redact sensitive information for logging
 */
export function redactSensitiveData<T extends Record<string, any>>(
  data: T,
  sensitiveFields: (keyof T)[]
): T {
  const redacted = { ...data };
  
  for (const field of sensitiveFields) {
    if (redacted[field]) {
      redacted[field] = '[REDACTED]' as any;
    }
  }
  
  return redacted;
}
