const { Octokit } = require("octokit");
const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// 1. Setup
const TOKEN_PATH = path.join(__dirname, '../github-token.txt');
const SERVICE_ACCOUNT_PATH = path.join(__dirname, '../service-account.json');

if (!fs.existsSync(TOKEN_PATH)) {
  console.error('Error: github-token.txt not found in project root.');
  process.exit(1);
}

const GITHUB_TOKEN = fs.readFileSync(TOKEN_PATH, 'utf8').trim();
const octokit = new Octokit({ auth: GITHUB_TOKEN });

const REPO_OWNER = 'maskbitter';
const REPO_NAME = 'akonssquare';

// Initialize Firebase Admin
const serviceAccount = require(SERVICE_ACCOUNT_PATH);
try {
  initializeApp({
    credential: cert(serviceAccount)
  });
} catch (e) {}
const db = getFirestore();

async function uploadToGithub() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node upload_to_github.js <local_apk_path> <version_string>');
    process.exit(1);
  }

  const localPath = args[0];
  const versionString = args[1];
  const tag = `v${versionString.replace('+', '_')}`;
  const fileName = `AkonsSquare_V${versionString.replace('+', '_')}_release.apk`;

  console.log(`--- Preparing GitHub Release for Tag: ${tag} ---`);

  try {
    // 2. Handle Release
    let release;
    try {
        const existing = await octokit.rest.repos.getReleaseByTag({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            tag: tag,
        });
        release = existing.data;
        console.log(`Found existing release: ${release.html_url}`);
    } catch (e) {
        const created = await octokit.rest.repos.createRelease({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            tag_name: tag,
            name: `Release ${versionString}`,
            body: `Automated release for version ${versionString}`,
        });
        release = created.data;
        console.log(`Success: Release created at ${release.html_url}`);
    }

    // 3. Delete existing asset if present
    try {
        const assets = await octokit.rest.repos.listReleaseAssets({
            owner: REPO_OWNER,
            repo: REPO_NAME,
            release_id: release.id,
        });
        const existingAsset = assets.data.find(a => a.name === fileName);
        if (existingAsset) {
            console.log(`Deleting existing asset: ${fileName}`);
            await octokit.rest.repos.deleteReleaseAsset({
                owner: REPO_OWNER,
                repo: REPO_NAME,
                asset_id: existingAsset.id,
            });
        }
    } catch (e) {}

    // 4. Upload APK
    console.log(`--- Uploading APK: ${fileName} ---`);
    const fileData = fs.readFileSync(localPath);

    const { data: asset } = await octokit.rest.repos.uploadReleaseAsset({
      owner: REPO_OWNER,
      repo: REPO_NAME,
      release_id: release.id,
      name: fileName,
      data: fileData,
      headers: {
        'content-type': 'application/vnd.android.package-archive',
        'content-length': fileData.length,
      },
    });

    const downloadUrl = asset.browser_download_url;
    console.log(`Success: APK uploaded. Direct URL: ${downloadUrl}`);

    // 5. Update Firestore
    console.log(`--- Updating Firestore requiredVersion to ${versionString} ---`);
    await db.collection('app_config').doc('settings').set({
      requiredVersion: versionString,
      downloadUrl: downloadUrl,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    console.log('Success: Firestore updated. Users will see the correct link.');
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

uploadToGithub();
