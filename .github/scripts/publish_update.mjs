import firebase from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const b64 = process.env.FIREBASE_SA_B64;
if (!b64) {
  console.log('FIREBASE_SA_B64 not set - skipping Firestore publish');
  process.exit(0);
}

const sa = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
firebase.initializeApp({ credential: firebase.cert(sa) });

const buildNumber = 1000 + Number(process.env.BUILD_NUMBER || '0');
const version = process.env.APP_VERSION || '1.0.0';
const commitMsg = (process.env.COMMIT_MSG || '').trim().slice(0, 200);
const apkUrl =
  'https://github.com/MIDO12A/zoro-app/releases/download/latest/zero-app.apk';

await getFirestore().doc('app_config/app_update').set(
  {
    latest_version: version,
    build_number: buildNumber,
    apk_url: apkUrl,
    notes_ar: commitMsg,
    notes_en: commitMsg,
    force_update: false,
    published_at: new Date().toISOString(),
  },
  { merge: true },
);

console.log(`Published update v${version} build ${buildNumber} -> ${apkUrl}`);
process.exit(0);
