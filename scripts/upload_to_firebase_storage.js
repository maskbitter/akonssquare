const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, '../service-account.json');

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('Error: service-account.json not found.');
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);
initializeApp({
  credential: cert(serviceAccount),
  storageBucket: 'akons-square.firebasestorage.app'
});

const db = getFirestore();
const bucket = getStorage().bucket();

async function uploadToFirebase() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node upload_to_firebase_storage.js <local_apk_path> <version_string>');
    process.exit(1);
  }

  const localPath = args[0];
  const versionString = args[1];
  const fileName = path.basename(localPath);
  const destination = `releases/${fileName}`;

  console.log(`--- Starting AkonsSquare Firebase Release Process ---`);

  try {
    // 1. Clean up old versions
    console.log(`--- Step 1: Cleaning up old versions from Firebase Storage... ---`);
    const [files] = await bucket.getFiles({ prefix: 'releases/' });
    if (files.length > 0) {
        console.log(`Found ${files.length} old file(s). Deleting...`);
        await Promise.all(files.map(file => file.delete()));
        console.log('Cleanup complete.');
    } else {
        console.log('No old versions found.');
    }

    // 2. Upload the NEW APK
    console.log(`--- Step 2: Uploading NEW APK: ${fileName} ---`);
    await bucket.upload(localPath, {
      destination: destination,
      metadata: {
        contentType: 'application/vnd.android.package-archive',
      },
    });

    // 3. Get Signed URL
    const file = bucket.file(destination);
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '01-01-2099', // Long expiry
    });

    console.log(`Success: New APK uploaded to Firebase Storage.`);

    // 4. Update Firestore Config
    console.log(`--- Step 3: Updating Firestore Config ---`);
    const batch = db.batch();

    const settingsRef = db.collection('app_config').doc('settings');
    batch.set(settingsRef, {
      requiredVersion: versionString,
      downloadUrl: url,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    // Update globalBuildNumber if BN is in filename
    if (fileName.includes("_BN")) {
        const bnMatch = fileName.match(/_BN(\d+)_/);
        if (bnMatch) {
            const newBN = parseInt(bnMatch[1]);
            const dbInfoRef = db.collection('app_config').doc('database_info');
            batch.set(dbInfoRef, {
                globalBuildNumber: newBN,
                lastUpdatedBy: "Firebase Upload Script"
            }, { merge: true });
        }
    }

    await batch.commit();
    console.log(`--- SUCCESS: Released ${versionString} via Firebase Storage ---`);
    console.log(`Direct Download URL: ${url}`);
    process.exit(0);

  } catch (error) {
    console.error('CRITICAL ERROR DURING RELEASE:', error.message);
    process.exit(1);
  }
}

uploadToFirebase();
