import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

function initApp(): App {
  const existing = getApps();
  if (existing.length) return existing[0];

  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
  if (b64) {
    const json = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
    return initializeApp({ credential: cert(json), projectId: json.project_id });
  }

  // Local dev: relies on GOOGLE_APPLICATION_CREDENTIALS or gcloud ADC.
  return initializeApp();
}

const app = initApp();

export const db = getFirestore(app);
export const auth = getAuth(app);
export const firebaseWebApiKey = process.env.FIREBASE_WEB_API_KEY || '';
