import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { supabase } from '../config/database';
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

    const agency = {
      id: uuidv4(),
      name,
      code,
      owner_uid: ownerUid,
      commission_rate: 10,
      total_earnings: 0,
      member_count: 1,
      status: 'active',
      created_at: new Date().toISOString(),
    };

    const { error } = await supabase.from('agencies').insert(agency);

    if (error) {
      res.status(400).json({ error: error.message });
      return;
    }

    await supabase.from('users').update({ role: 'agent', agency_id: agency.id }).eq('uid', ownerUid);

    res.status(201).json({ agency });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/my', authenticate, async (req: Request, res: Response) => {
  try {
    const uid = req.user!.uid;

    const { data: membership } = await supabase
      .from('agency_members')
      .select('agency_id')
      .eq('user_uid', uid)
      .maybeSingle();

    const agencyId = membership?.agency_id;

    if (!agencyId) {
      const { data: ownedAgency } = await supabase
        .from('agencies')
        .select('*')
        .eq('owner_uid', uid)
        .single();

      if (ownedAgency) {
        const { data: members } = await supabase
          .from('agency_members')
          .select('*')
          .eq('agency_id', ownedAgency.id);

        res.json({ agency: ownedAgency, members: members || [] });
        return;
      }

      res.json({ agency: null, members: [] });
      return;
    }

    const { data: agency } = await supabase
      .from('agencies')
      .select('*')
      .eq('id', agencyId)
      .single();

    const { data: members } = await supabase
      .from('agency_members')
      .select('*')
      .eq('agency_id', agencyId);

    res.json({ agency, members: members || [] });
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

    const { data: agency, error: findError } = await supabase
      .from('agencies')
      .select('*')
      .eq('code', code)
      .single();

    if (findError || !agency) {
      res.status(404).json({ error: 'Agency not found' });
      return;
    }

    if (agency.status !== 'active') {
      res.status(400).json({ error: 'Agency is suspended' });
      return;
    }

    const { data: existing } = await supabase
      .from('agency_members')
      .select('id')
      .eq('agency_id', agency.id)
      .eq('user_uid', userUid)
      .maybeSingle();

    if (existing) {
      res.status(400).json({ error: 'Already a member of this agency' });
      return;
    }

    const member = {
      id: uuidv4(),
      agency_id: agency.id,
      user_uid: userUid,
      role: 'sub_agent',
      commission_rate: agency.commission_rate - 2,
      joined_at: new Date().toISOString(),
    };

    const { error: joinError } = await supabase.from('agency_members').insert(member);

    if (joinError) {
      res.status(500).json({ error: joinError.message });
      return;
    }

    await supabase
      .from('agencies')
      .update({ member_count: agency.member_count + 1 })
      .eq('id', agency.id);

    await supabase.from('users').update({ role: 'agent', agency_id: agency.id }).eq('uid', userUid);

    res.status(201).json({ agency, member });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/add-agent', authenticate, requireRole('admin'), async (req: Request, res: Response) => {
  try {
    const { agencyId, userUid, commissionRate } = req.body;

    const member = {
      id: uuidv4(),
      agency_id: agencyId,
      user_uid: userUid,
      role: 'agent',
      commission_rate: commissionRate || 10,
      joined_at: new Date().toISOString(),
    };

    const { error } = await supabase.from('agency_members').insert(member);

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    await supabase.from('users').update({ role: 'agent', agency_id: agencyId }).eq('uid', userUid);

    res.status(201).json({ member });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

router.get('/all', authenticate, requireRole('admin'), async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('agencies')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      res.status(500).json({ error: error.message });
      return;
    }

    res.json({ agencies: data });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
