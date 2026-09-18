import { spawn } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const workflowDirectory = join(scriptDirectory, '..', 'workflows');

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) return resolve();
      reject(new Error(`${command} ${args.join(' ')} failed (${code}): ${stderr.trim() || stdout.trim()}`));
    });
  });
}

await run('docker', [
  'run', '--rm',
  '-e', 'N8N_ENCRYPTION_KEY=local-test-encryption-key-that-is-long-enough',
  '-e', 'N8N_USER_FOLDER=/tmp/n8n',
  '-v', `${workflowDirectory}:/files/workflows:ro`,
  'n8nio/n8n:2.39.8',
  'import:workflow',
  '--separate',
  '--input=/files/workflows',
]);

console.log('Imported all workflows with the pinned n8n runtime.');
