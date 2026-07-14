import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { createPublicKey, createVerify } from 'node:crypto';
import { getFormData, requestHandler, HTTPError } from 'web-listener';

export default requestHandler(async (req, res) => {
  const fields = await getFormData(req, {
    maxContentBytes: 2 * 1024,
    maxFields: 2,
    maxFiles: 0,
  });

  const detail = fields.getString('detail');
  const signature = fields.getString('signature');
  if (!detail || !signature || signature.length !== 1024) {
    throw new HTTPError(400, { body: 'invalid request' });
  }

  const [rawTime, service] = detail.split(';');
  if (!ISO_TIMESTAMP.test(rawTime) || !service) {
    throw new HTTPError(400, { body: 'invalid request' });
  }

  const verifier = createVerify('RSA-SHA256');
  verifier.update(detail, 'utf-8');
  if (!verifier.verify(DEPLOY_PUBLIC, signature, 'hex')) {
    throw new HTTPError(400, { body: 'invalid signature' });
  }

  const now = Date.now();
  const time = Date.parse(rawTime);
  if (time > now + MAX_CLOCK_SKEW) {
    throw new HTTPError(400, { body: 'timestamp is in the future' });
  }
  if (time < now - MAX_REQUEST_AGE) {
    throw new HTTPError(400, { body: 'timestamp is too old' });
  }

  try {
    await throttledScheduleUpdate();
  } catch (error) {
    throw new HTTPError(500, {
      body: 'failed to trigger update job',
      message: `failed to trigger update job: ${error.message}`,
    });
  }

  res.setHeader('content-type', 'text/plain; charset=utf-8');
  res.setHeader('x-content-type-options', 'nosniff');
  res.statusCode = 202;
  res.end('deployment request queued');
});

const BASEDIR = dirname(fileURLToPath(import.meta.url));

const DEPLOY_PUBLIC = createPublicKey({
  key: await readFile(join(BASEDIR, 'public.pem')),
  format: 'pem',
});

const ISO_TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/;
const MAX_CLOCK_SKEW = 60 * 1000;
const MAX_REQUEST_AGE = 10 * 60 * 1000;

const THROTTLE_TIME = 10 * 1000;
let throttlePromise = null;
let lastRun = 0;

function scheduleUpdate() {
  lastRun = Date.now();
  throttlePromise = null;

  return new Promise((resolve, reject) => {
    // this specific command is enabled for the web-listener user via sudoers
    const proc = spawn('sudo', ['/usr/bin/systemctl', 'start', 'web-listener-updater'], { stdio: 'ignore', timeout: 10000 });
    proc.once('error', reject);
    proc.once('exit', (code, signal) => {
      if (code) {
        reject(new Error(`exit code ${code}`));
      } else if (signal) {
        reject(new Error(`signal ${signal}`));
      } else {
        resolve();
      }
    });
  });
}

function throttledScheduleUpdate() {
  if (throttlePromise) {
    return throttlePromise;
  }
  const delay = lastRun + THROTTLE_TIME - now;
  if (delay >= 0) {
    throttlePromise = new Promise((resolve) => setTimeout(resolve, delay)).then(scheduleUpdate);
    return throttlePromise;
  }
  return scheduleUpdate();
}
