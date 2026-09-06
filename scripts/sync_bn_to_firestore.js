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

async function syncBN() {
  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.error('Usage: node sync_bn_to_firestore.js <new_bn>');
    process.exit(1);
  }

  const newBN = parseInt(args[0]);
  console.log(`--- Syncing Global Build Number to Firestore: ${newBN} ---`);

  try {
    await db.collection('app_config').doc('database_info').set({
      globalBuildNumber: newBN,
      lastUpdatedBy: "Automation Script",
      updatedAt: new Date()
    }, { merge: true });
    console.log('Success: Firestore Global Build Number updated.');
    process.exit(0);
  } catch (error) {
    console.error('Error updating Firestore:', error);
    process.exit(1);
  }
}

syncBN();
