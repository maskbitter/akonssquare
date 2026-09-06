const fs = require('fs');
const path = require('path');
const { initializeApp, cert, getApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, '../service-account.json');

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('Error: service-account.json not found.');
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);

// Robust initialization
if (!getApps().length) {
  initializeApp({
    credential: cert(serviceAccount)
  });
}

const db = getFirestore();

// Read current BN and Version from build_config.dart
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
  console.log(`Updating Firestore BN: ${buildNumber} (Version: ${appVersion})...`);

  try {
    // Update database_info (Tracking current build)
    await db.collection('app_config').doc('database_info').set({
      buildNumber: buildNumber,
      globalBuildNumber: buildNumber,
      bnUpdatedAt: FieldValue.serverTimestamp(),
      lastUpdatedBy: 'Deployment Script'
    }, { merge: true });

    console.log('Successfully updated Firestore version metadata.');
    process.exit(0);
  } catch (error) {
    console.error('Failed to update Firestore:', error);
    process.exit(1);
  }
}

updateFirestore();
