#!/usr/bin/env -S node --disable-proto=delete --disallow-code-generation-from-strings --force-node-api-uncaught-exceptions-policy --no-addons --disable-sigusr1
import { dirname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createReadStream, createWriteStream } from 'node:fs';
import { access, chmod, chown, readdir, readFile, rename, rm, writeFile } from 'node:fs/promises';
import { pipeline } from 'node:stream/promises';
import { spawnSync } from 'node:child_process';
import { createPublicKey, createVerify } from 'node:crypto';

const selfDir = dirname(fileURLToPath(import.meta.url));
const workDir = join(selfDir, 'update', 'work');
const stateFile = join(workDir, 'state.json');
const sitesDir = resolve(selfDir, './sites');
const configFile = join(sitesDir, 'config.json');
const WEB_LISTENER_BINARY = 'web-listener';
const RUNNER_GID = await getGID('web-listener-runner');

const sites = JSON.parse(await readFile(join(selfDir, 'sites.json'), { encoding: 'utf-8' }));
let state;
try {
  state = JSON.parse(await readFile(stateFile, { encoding: 'utf-8' }));
} catch {
  state = { urls: [], sites: [] };
}

const now = Date.now();
let loaded = false;
let changed = false;
let failed = false;
const newSites = [];
for (const site of sites) {
  const url = site.url;
  try {
    process.stderr.write(`checking ${site.name} ${url}\n`);
    const zipFile = join(workDir, 'download.zip');
    if (!await loadFileIfChanged(url, zipFile)) {
      process.stderr.write(`no change to ${site.name} ${url}\n`);
      newSites.push(state.sites.find((o) => o.name === site.name));
      continue;
    }
    process.stderr.write(`updating ${site.name} ${url}\n`);
    loaded = true;

    const targetDir = join(sitesDir, `${site.name}-${now}`);
    if (await access(targetDir).then(() => true, () => false)) {
      throw new Error(`Directory ${targetDir} already exists`);
    }
    await extractZip(zipFile, targetDir);
    await validateSignatures(targetDir, resolve(selfDir, site.publicKeyFile));

    for (const file of await readdir(targetDir, { encoding: 'utf-8' })) {
      if (file !== 'web-bundle.zip' && file.endsWith('.zip')) {
        await extractZip(join(targetDir, file), targetDir);
      }
    }

    await setPermissionGroupRecursive(targetDir, 0o640, RUNNER_GID);
    const siteConfigFile = resolve(targetDir, './web-bundle.zip/config.json');

    checkError(spawnSync(
      WEB_LISTENER_BINARY,
      ['-c', siteConfigFile, '--no-serve'],
      { stdio: ['ignore', 'ignore', 'inherit'] },
    ));

    newSites.push({ name: site.name, config: siteConfigFile });
    changed = true;
  } catch (error) {
    const oldSite = state.sites.find((o) => o.name === site.name);
    if (oldSite) {
      newSites.push(oldSite);
    }
    process.stderr.write(`Failed to update ${site.name} ${url}: ${error}\n`);
    failed = true;
  }
}

if (changed) {
  process.stderr.write('Updating top-level configuration\n');
  await rm(configFile + '.rollback').catch(() => {});
  const hasOldConfig = await access(configFile).then(() => true, () => false);
  if (hasOldConfig) {
    await rename(configFile, configFile + '.rollback');
  }
  await writeFile(configFile, JSON.stringify({
    servers: [
      {
        port: 8080,
        mount: [
          ...newSites.map((site) => ({ type: 'delegate', 'path': `/${site.name}`, config: { file: site.config } })),
          { type: 'custom', method: 'POST', path: '/', 'import': resolve(selfDir, './deploy.mjs') },
        ],
      },
    ],
    log: { format: 'json' },
  }, undefined, 2), { encoding: 'utf-8' });
  await chmod(configFile, 0o644);
  await chown(configFile, -1, RUNNER_GID);

  try {
    // test config before attempting to restart services
    checkError(spawnSync(
      WEB_LISTENER_BINARY,
      ['-c', configFile, '--no-serve'],
      { stdio: ['ignore', 'ignore', 'inherit'] },
    ));

    if (!process.argv.includes('--nostart')) {
      process.stderr.write('Restarting services\n');
      for (const port of [8080, 8081]) {
        // permission for this sudo command is granted in 50-web-listener-updater
        checkError(spawnSync(
          'sudo',
          ['systemctl', 'restart', `web-listener${port}`],
          { stdio: ['ignore', 'ignore', 'inherit'] },
        ));
      }
    }
    state.sites = newSites;
  } catch (error) {
    process.stderr.write(`New config failed validation: ${error}\n`);
    if (hasOldConfig) {
      process.stderr.write('Rolling back\n');
      await rm(configFile);
      await rename(configFile + '.rollback', configFile);
    }
    failed = true;
  }

  process.stderr.write('Deleting unused sites\n');

  const latestConfig = JSON.parse(await readFile(configFile, { encoding: 'utf-8' }));
  for (const sub of await readdir(sitesDir, { encoding: 'utf-8', withFileTypes: true })) {
    if (!sub.isDirectory()) {
      continue;
    }
    const fullPath = join(sitesDir, sub.name);
    if (!latestConfig.servers[0].mount.some((o) => o.config?.file?.startsWith(fullPath + sep))) {
      process.stderr.write(`Removing ${fullPath}\n`);
      await rm(fullPath, { recursive: true });
    }
  }
  await rm(configFile + '.rollback').catch(() => {});
} else {
  process.stderr.write('No changes\n');
}

if (loaded) {
  process.stderr.write('Recording latest state\n');
  await writeFile(
    stateFile,
    JSON.stringify(state),
    { encoding: 'utf-8', mode: 0o600 },
  );
}

if (failed) {
  process.exit(1);
}

async function loadFileIfChanged(url, target) {
  let urlState = state.urls.find((s) => s.url === url);
  const headers = {};
  if (urlState?.lastEtag) {
    headers['if-none-match'] = urlState.lastEtag;
  }
  if (urlState?.lastModified) {
    headers['if-modified-since'] = urlState.lastModified;
  }
  const response = await fetch(url, { redirect: 'follow', headers });
  if (response.status === 304) {
    return false;
  }
  if (response.status !== 200) {
    throw new Error(`HTTP ${response.status}`);
  }
  await rm(target).catch(() => {});
  await pipeline(
    response.body,
    createWriteStream(target, { mode: 0o600 }),
  );
  if (!urlState) {
    urlState = { url };
    state.urls.push(urlState);
  }
  urlState.lastEtag = response.headers.get('etag') || null;
  urlState.lastModified = response.headers.get('last-modified') || null;
  return true;
}

function checkError(spawnResult) {
  if (spawnResult.error) {
    throw spawnResult.error;
  }
  if (spawnResult.status !== 0) {
    throw new Error(`executable exited with code ${spawnResult.status}`);
  }
}

async function extractZip(zipFile, targetDir) {
  try {
    checkError(spawnSync(
      'unzip',
      [zipFile, '-d', join(targetDir)],
      { stdio: ['ignore', 'ignore', 'inherit'] },
    ));
    await rm(zipFile);
  } catch (error) {
    throw new Error(`Failed to unzip: ${error}`)
  }
}

async function validateSignatures(dir, publicKeyFile) {
  const publicKey = createPublicKey({
    key: await readFile(publicKeyFile),
    format: 'pem',
  });
  for (const file of await readdir(dir, { encoding: 'utf-8' })) {
    if (file.endsWith('.sign')) {
      continue;
    }
    const signatureFile = join(dir, file + '.sign');
    const signature = await readFile(signatureFile);

    const verifier = createVerify('RSA-SHA256');
    await pipeline(createReadStream(join(dir, file)), verifier);
    if (!verifier.verify(publicKey, signature)) {
      throw new Error(`Incorrect signature for ${file}`);
    }
    await rm(signatureFile);
  }
  for (const file of await readdir(dir, { encoding: 'utf-8' })) {
    if (file.endsWith('.sign')) {
      throw new Error(`Unexpected signature file: ${file}`);
    }
  }
}

async function setPermissionGroupRecursive(dir, permission, group) {
  for (const sub of await readdir(dir, { encoding: 'utf-8', withFileTypes: true })) {
    const fullPath = join(dir, sub.name);
    if (sub.isDirectory()) {
      await chmod(
        fullPath,
        permission |
          ((permission & 0o400) ? 0o100 : 0) |
          ((permission & 0o040) ? 0o010 : 0) |
          ((permission & 0o004) ? 0o001 : 0),
      );
      await chown(fullPath, -1, group);
      await setPermissionGroupRecursive(fullPath, permission, group);
    } else if (sub.isFile()) {
      await chmod(fullPath, permission);
      await chown(fullPath, -1, group);
    }
  }
}

async function getGID(group) {
  for (const ln of (await readFile('/etc/group', { encoding: 'utf-8' })).split('\n')) {
    const parts = ln.split(':');
    if (parts[0] === group) {
      return Number.parseInt(parts[2], 10);
    }
  }
  throw new Error(`unknown group ${group}`);
}
