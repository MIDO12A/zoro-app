import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { db } from '../config/database';
import { auth } from '../config/firebase';
import { AuthPayload } from '../types';

declare global {
  namespace Express {
    interface Request {
      user?: AuthPayload;
    }
  }
}

async function verifyFirebaseIdToken(token: string): Promise<AuthPayload | null> {
  try {
    const decoded = await auth.verifyIdToken(token);
    if (!decoded?.uid) return null;
    return { uid: decoded.uid, role: 'user' };
  } catch {
    return null;
  }
}

async function verifyCustomToken(token: string): Promise<AuthPayload | null> {
  try {
    const payload = jwt.verify(token, config.jwt.secret) as AuthPayload;
    return payload;
  } catch {
    return null;
  }
}

async function resolveRole(uid: string): Promise<AuthPayload['role']> {
  try {
    // Admins of the dashboard live in admin_users; app-level admins in users.role.
    const adminDoc = await db.collection('admin_users').doc(uid).get();
    if (adminDoc.exists) return 'admin';
    const userDoc = await db.collection('users').doc(uid).get();
    const role = (userDoc.data()?.role as string) || 'user';
    return (role === 'admin' || role === 'agent' ? role : 'user') as AuthPayload['role'];
  } catch {
    return 'user';
  }
}

export async function authenticate(req: Request, res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Unauthorized: No token provided' });
    return;
  }

  const token = authHeader.slice(7);

  let payload = await verifyCustomToken(token);
  if (!payload) {
    payload = await verifyFirebaseIdToken(token);
  }

  if (!payload) {
    res.status(401).json({ error: 'Unauthorized: Invalid token' });
    return;
  }

  req.user = { ...payload, role: await resolveRole(payload.uid) };
  next();
}

export async function optionalAuth(req: Request, _res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    let payload = await verifyCustomToken(token);
    if (!payload) {
      payload = await verifyFirebaseIdToken(token);
    }
    if (payload) {
      req.user = { ...payload, role: await resolveRole(payload.uid) };
    }
  }
  next();
}

export function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    if (!roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Forbidden: Insufficient permissions' });
      return;
    }
    next();
  };
}

export function generateToken(payload: AuthPayload): string {
  return jwt.sign(payload, config.jwt.secret, { expiresIn: config.jwt.expiresIn as any });
}
