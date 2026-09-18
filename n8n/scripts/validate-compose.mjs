import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const automationDirectory = join(dirname(fileURLToPath(import.meta.url)), '..');

await new Promise((resolve, reject) => {
  const child = spawn('docker', ['compose', '--env-file', '.env.example', 'config', '-q'], {
    cwd: automationDirectory,
    env: { ...process.env, N8N_ENV_FILE: '.env.example' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  child.stdout.on('data', (chunk) => { output += chunk; });
  child.stderr.on('data', (chunk) => { output += chunk; });
  child.on('error', reject);
  child.on('close', (code) => {
    if (code === 0) return resolve();
    reject(new Error(`docker compose config failed: ${output.trim()}`));
  });
});

console.log('Validated the local n8n Docker Compose configuration.');
