import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../config/database';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

router.post('/create', authenticate, async (req: Request, res: Response) => {
  try {
    const { name } = req.body;
    const ownerUid = req.user!.uid;

    if (!name) {
      res.status(400).json({ error: 'Agency name is required' });
      return;
    }

    const code = 'AG' + String(1000 + Math.floor(Math.random() * 9000));

    const agencyId = uuidv4();
    const agency = {
      id: agencyId,
      name,
      code,
      owner_uid: ownerUid,
      commission_rate: 10,
      total_earnings: 0,
      member_count: 1,
      status: 'active',
      created_at: new Date().toISOString(),
    };

    await db.collection('agencies').doc(agencyId).set(agency);

    await db.collection('users').doc(ownerUid).set({ role: 'agent', agency_id: agencyId }, { merge: true });

    res.status(201).json({ agency });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/my', authenticate, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.uid;

    const membershipSnap = await db
      .collection('agency_members')
      .where('user_uid', '==', uid)
      .limit(1)
      .get();

    const agencyId = membershipSnap.empty ? undefined : membershipSnap.docs[0].data().agency_id;

    let agencyDoc = null;
    if (agencyId) {
      agencyDoc = await db.collection('agencies').doc(agencyId).get();
    }

    if (!agencyId || !agencyDoc!.exists) {
      const ownedSnap = await db
        .collection('agencies')
        .where('owner_uid', '==', uid)
        .limit(1)
        .get();

      if (!ownedSnap.empty) {
        const ownedAgency = ownedSnap.docs[0].data();
        const membersSnap = await db
          .collection('agency_members')
          .where('agency_id', '==', ownedAgency.id)
          .get();

        res.json({
          agency: ownedAgency,
          members: membersSnap.docs.map(d => d.data()),
        });
        return;
      }

      res.json({ agency: null, members: [] });
      return;
    }

    const membersSnap = await db
      .collection('agency_members')
      .where('agency_id', '==', agencyId)
      .get();

    res.json({
      agency: agencyDoc!.data(),
      members: membersSnap.docs.map(d => d.data()),
    });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/join', authenticate, async (req: Request, res: Response) => {
  try {
    const { code } = req.body;
    const userUid = req.user!.uid;

    if (!code) {
      res.status(400).json({ error: 'Agency code is required' });
      return;
    }

    const agencySnap = await db.collection('agencies').where('code', '==', code).limit(1).get();
    if (agencySnap.empty) {
      res.status(404).json({ error: 'Agency not found' });
      return;
    }

    const agencyDoc = agencySnap.docs[0];
    const agency = agencyDoc.data() as any;

    if (agency.status !== 'active') {
      res.status(400).json({ error: 'Agency is suspended' });
      return;
    }

    const existingSnap = await db
      .collection('agency_members')
      .where('agency_id', '==', agency.id)
      .where('user_uid', '==', userUid)
      .limit(1)
      .get();

    if (!existingSnap.empty) {
      res.status(400).json({ error: 'Already a member of this agency' });
      return;
    }

    const memberId = uuidv4();
    const member = {
      id: memberId,
      agency_id: agency.id,
      user_uid: userUid,
      role: 'sub_agent',
      commission_rate: agency.commission_rate - 2,
      joined_at: new Date().toISOString(),
    };

    await db.runTransaction(async tx => {
      tx.set(db.collection('agency_members').doc(memberId), member);
      tx.update(db.collection('agencies').doc(agencyDoc.id), {
        member_count: FieldValue.increment(1),
      });
    });

    await db.collection('users').doc(userUid).set({ role: 'agent', agency_id: agency.id }, { merge: true });

    res.status(201).json({ agency, member });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/add-agent', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { agencyId, userUid, commissionRate } = req.body;

    const memberId = uuidv4();
    const member = {
      id: memberId,
      agency_id: agencyId,
      user_uid: userUid,
      role: 'agent',
      commission_rate: commissionRate || 10,
      joined_at: new Date().toISOString(),
    };

    await db.collection('agency_members').doc(memberId).set(member);

    await db.collection('users').doc(userUid).set({ role: 'agent', agency_id: agencyId }, { merge: true });

    res.status(201).json({ member });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/all', authenticate, requireRole('admin'), async (_req: Request, res: Response) => {
  try {
    const snap = await db.collection('agencies').orderBy('created_at', 'desc').get();

    res.json({ agencies: snap.docs.map(d => d.data()) });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
