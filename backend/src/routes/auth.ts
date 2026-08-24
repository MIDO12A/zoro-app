import { Router, Request, Response } from 'express';
import { db, firebaseWebApiKey } from '../config/database';
import { auth } from '../config/firebase';
import { generateToken } from '../middleware/auth';
import { authenticate } from '../middleware/auth';

const router = Router();

interface RestSignInResult {
  localId: string;
  idToken: string;
}

async function restSignIn(email: string, password: string): Promise<RestSignInResult | null> {
  try {
    const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${firebaseWebApiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      }
    );
    if (!res.ok) return null;
    const data = (await res.json()) as { localId?: string; idToken?: string };
    const { localId, idToken } = data;
    if (!localId || !idToken) return null;
    return { localId, idToken };
  } catch {
    return null;
  }
}

router.post('/signup', async (req: Request, res: Response) => {
  try {
    const { email, password, name } = req.body;

    if (!email || !password || !name) {
      res.status(400).json({ error: 'Email, password, and name are required' });
      return;
    }

    let userRecord;
    try {
      userRecord = await auth.createUser({
        email,
        password,
        displayName: name,
        emailVerified: true,
      });
    } catch (authError: any) {
      res.status(400).json({ error: authError.message });
      return;
    }

    const uid = userRecord.uid;
    const customId = String(1000000 + Math.floor(Math.random() * 9000000));

    const userData = {
      uid,
      custom_id: customId,
      name,
      email,
      gender: 'male',
      coins: 10000,
      diamonds: 0,
      role: 'user',
      level: 1,
      created_at: new Date().toISOString(),
    };

    try {
      await db.collection('users').doc(uid).set(userData);
    } catch (dbError: any) {
      await auth.deleteUser(uid);
      res.status(400).json({ error: dbError.message });
      return;
    }

    const token = generateToken({ uid, role: 'user' });

    res.status(201).json({
      token,
      user: { uid, custom_id: customId, name, email, coins: 10000, diamonds: 0 },
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/login', async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'Email and password are required' });
      return;
    }

    const signIn = await restSignIn(email, password);

    if (!signIn) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const uid = signIn.localId;

    const doc = await db.collection('users').doc(uid).get();
    const profile = doc.exists ? doc.data() : undefined;

    if (profile?.banned) {
      res.status(403).json({ error: `Account banned: ${profile.ban_reason || 'No reason'}` });
      return;
    }

    const token = generateToken({ uid, role: ((profile?.role as string) || 'user') as any });

    res.json({
      token,
      user: profile ? { uid, ...profile } : { uid },
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/me', authenticate, async (req: Request, res: Response) => {
  try {
    const doc = await db.collection('users').doc(req.user!.uid).get();

    if (!doc.exists) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json({ user: doc.data() });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/account', authenticate, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.uid;

    await db.collection('users').doc(uid).delete();
    await auth.deleteUser(uid);

    res.json({ success: true, message: 'Account deleted permanently' });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/admin/login', async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;

    const signIn = await restSignIn(email, password);

    if (!signIn) {
      res.status(401).json({ error: 'Invalid email or password' });
      return;
    }

    const uid = signIn.localId;

    // Dashboard admins live in admin_users; app-level admins in users.role.
    const adminDoc = await db.collection('admin_users').doc(uid).get();
    let isAdmin = adminDoc.exists;

    if (!isAdmin) {
      const profile = await db.collection('users').doc(uid).get();
      isAdmin = profile.data()?.role === 'admin';
    }

    if (!isAdmin) {
      res.status(403).json({ error: 'Not an admin account' });
      return;
    }

    const token = generateToken({ uid, role: 'admin' });

    res.json({ token, uid });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
