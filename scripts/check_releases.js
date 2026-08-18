const { Octokit } = require("octokit");
const fs = require('fs');
const path = require('path');

const TOKEN_PATH = path.join(__dirname, '../github-token.txt');
const GITHUB_TOKEN = fs.readFileSync(TOKEN_PATH, 'utf8').trim();
const octokit = new Octokit({ auth: GITHUB_TOKEN });

async function run() {
  const { data: releases } = await octokit.rest.repos.listReleases({
    owner: 'maskbitter',
    repo: 'akonssquare',
  });

  releases.forEach(r => {
    console.log(`Tag: ${r.tag_name}, Name: ${r.name}`);
    r.assets.forEach(a => {
      console.log(`  - Asset: ${a.name}, URL: ${a.browser_download_url}`);
    });
  });
}

run();
