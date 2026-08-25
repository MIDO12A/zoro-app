import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import {
  getFirestore, doc, runTransaction, setDoc, deleteDoc,
} from 'firebase/firestore';

const cfg = {
  apiKey: 'AIzaSyBV61UNM2iTTTZcBEALxvWxvi17EFD9XOU',
  authDomain: 'zeroappzero-e1b4a.firebaseapp.com',
  projectId: 'zeroappzero-e1b4a',
  storageBucket: 'zeroappzero-e1b4a.firebasestorage.app',
  messagingSenderId: '95008435096',
};

const app = initializeApp(cfg);
const auth = getAuth(app);
const db = getFirestore(app);

const SENDER = 'test_txn_sender_a';
const RECEIVER = 'test_txn_receiver_b';
const ROOM = 'test_txn_room_r';

async function setup() {
  await setDoc(doc(db, 'users', SENDER), { name: 'T-A', coins: 100000, total_gifts_sent: 0 });
  await setDoc(doc(db, 'users', RECEIVER), { name: 'T-B', diamonds: 0, total_gifts_received: 0 });
  // NOTE: no user_wallets docs on purpose - mirrors real users
}

async function cleanup() {
  for (const [col, id] of [['users', SENDER], ['users', RECEIVER], ['rooms', ROOM]]) {
    try { await deleteDoc(doc(db, col, id)); } catch {}
  }
}

async function giftTxn(selfGift) {
  const senderId = SENDER;
  const receiverId = selfGift ? SENDER : RECEIVER;
  const value = 50, count = 1, totalCost = value * count;

  await runTransaction(db, async (txn) => {
    const senderRef = doc(db, 'users', senderId);
    const senderSnap = await txn.get(senderRef);
    if (!senderSnap.exists()) throw new Error('sender missing');
    const sc = senderSnap.data().coins ?? 0;
    if (sc < totalCost) throw new Error('insufficient');

    const receiverRef = doc(db, 'users', receiverId);
    const recvSnap = await txn.get(receiverRef);

    const roomRef = doc(db, 'rooms', ROOM);
    const roomSnap = await txn.get(roomRef);

    const walletRef = doc(db, 'user_wallets', receiverId);   // <-- read OTHER user's wallet
    const wSnap = await txn.get(walletRef);

    txn.set(doc(db, 'sent_gifts', 'test_' + Date.now()), { test: true, value });

    txn.update(senderRef, { coins: sc - totalCost });

    if (recvSnap.exists()) {
      const rd = recvSnap.data();
      txn.update(receiverRef, {
        diamonds: (rd.diamonds ?? 0) + totalCost,
        total_gifts_received: (rd.total_gifts_received ?? 0) + totalCost,
      });
    }
    if (roomSnap.exists()) {
      txn.update(roomRef, { total_gifts: 10 });
    } else {
      txn.set(roomRef, { total_gifts: 10 });
    }
    if (wSnap.exists()) {
      const wd = wSnap.data();
      txn.update(walletRef, { diamond_balance: (wd.diamond_balance ?? 0) + totalCost });
    } else {
      txn.set(walletRef, { user_id: receiverId, diamond_balance: totalCost, gold_balance: 0 });
    }
  });
}

const mode = process.argv[2] || 'other';
try {
  const cred = await signInAnonymously(auth);
  console.log('signed in as', cred.user.uid);
  await cleanup();
  await setup();
  await giftTxn(mode === 'self');
  console.log(mode === 'self' ? 'SELF-GIFT TXN OK' : 'OTHER-GIFT TXN OK');
} catch (e) {
  console.log('TXN FAILED:', e.code || '', e.message);
} finally {
  try { await cleanup(); } catch {}
  process.exit(0);
}
