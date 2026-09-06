const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, '../service-account.json');

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);
initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function getBN() {
  try {
    const snap = await db.collection('app_config').doc('database_info').get();
    if (snap.exists) {
      console.log(snap.data().globalBuildNumber || 0);
    } else {
      console.log(0);
    }
    process.exit(0);
  } catch (e) {
    process.exit(1);
  }
}

getBN();
