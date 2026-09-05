const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// 1. Initialize Firebase Admin
const serviceAccount = require('../service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 2. Read build_config.dart
const buildConfigPath = path.join(__dirname, '../lib/Common/build_config.dart');
const buildConfigContent = fs.readFileSync(buildConfigPath, 'utf8');

const buildNumberMatch = buildConfigContent.match(/const int buildNumber = (\d+);/);
const appVersionMatch = buildConfigContent.match(/const String appVersion = "([^"]+)";/);

if (!buildNumberMatch || !appVersionMatch) {
  console.error('Error: Could not parse buildNumber or appVersion from build_config.dart');
  process.exit(1);
}

const buildNumber = parseInt(buildNumberMatch[1]);
const appVersion = appVersionMatch[1];

async function updateFirestore() {
  console.log(`Updating Firestore with Version: ${appVersion} (BN${buildNumber})...`);

  try {
    // Update database_info
    await db.collection('app_config').doc('database_info').set({
      buildNumber: buildNumber,
      bnUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Update settings (requiredVersion)
    await db.collection('app_config').doc('settings').set({
      requiredVersion: appVersion,
      versionUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log('Successfully updated Firestore version metadata.');
    process.exit(0);
  } catch (error) {
    console.error('Failed to update Firestore:', error);
    process.exit(1);
  }
}

updateFirestore();
