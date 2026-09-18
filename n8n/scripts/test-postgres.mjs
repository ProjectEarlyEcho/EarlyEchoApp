import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const rootDirectory = join(scriptDirectory, '..', '..');
const fixturePath = join(rootDirectory, 'n8n', 'tests', 'automation-integration-schema.sql');
const migrationPath = join(rootDirectory, 'supabase', 'migrations', '202609190002_automation_outbox.sql');
const containerName = `earlyecho-automation-test-${process.pid}`;
const database = 'automation_test';
const asOf = '2026-09-18T21:00:00Z';

function run(command, args, { input } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    child.stderr.on('data', (chunk) => { stderr += chunk; });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) return resolve(stdout.trim());
      reject(new Error(`${command} ${args.join(' ')} failed (${code}): ${stderr.trim() || stdout.trim()}`));
    });
    child.stdin.end(input);
  });
}

const delay = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitForPostgres() {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    try {
      const logs = await run('docker', ['logs', containerName]);
      if (!logs.includes('PostgreSQL init process complete; ready for start up.')) {
        await delay(500);
        continue;
      }
      await run('docker', ['exec', containerName, 'psql', '-U', 'postgres', '-d', database, '-c', 'select 1']);
      return;
    } catch {
      await delay(500);
    }
  }
  throw new Error('Timed out waiting for disposable PostgreSQL to start.');
}

async function runSql(sql, { tuplesOnly = false } = {}) {
  const options = tuplesOnly ? ['-At', '-F', '\t'] : [];
  return run('docker', [
    'exec', '-i', containerName, 'psql', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', database, ...options,
  ], { input: sql });
}

function rows(output) {
  return output.split(/\r?\n/).filter(Boolean).map((row) => row.split('\t'));
}

const seedSql = `
insert into auth.users (id, email, email_confirmed_at) values
  ('00000000-0000-0000-0000-000000000001', 'red.parent@example.test', '2026-01-01T00:00:00Z'),
  ('00000000-0000-0000-0000-000000000002', 'yellow.parent@example.test', '2026-01-01T00:00:00Z'),
  ('00000000-0000-0000-0000-000000000003', 'appointment.parent@example.test', '2026-01-01T00:00:00Z'),
  ('00000000-0000-0000-0000-000000000004', 'clinician@example.test', '2026-01-01T00:00:00Z');

insert into public.profiles (id, role, display_name) values
  ('00000000-0000-0000-0000-000000000001', 'parent', 'Riya Parent'),
  ('00000000-0000-0000-0000-000000000002', 'parent', 'Yusuf Parent'),
  ('00000000-0000-0000-0000-000000000003', 'parent', 'Asha Parent'),
  ('00000000-0000-0000-0000-000000000004', 'clinician', 'Dr. Sen');

insert into public.children (id, display_name) values
  ('10000000-0000-0000-0000-000000000001', 'Mira'),
  ('10000000-0000-0000-0000-000000000002', 'Kabir'),
  ('10000000-0000-0000-0000-000000000003', 'Tara');

insert into public.child_guardians (child_id, parent_id) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003');

insert into public.screening_sessions (id, child_id, created_at, analysis_status, risk_level) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '2026-09-01T12:00:00Z', 'COMPLETE', 'red'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '2026-06-01T12:00:00Z', 'COMPLETE', 'yellow');

insert into public.appointments (id, child_id, parent_id, clinician_id, starts_at, status, created_at) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', '2026-09-19T21:00:00Z', 'confirmed', '2026-09-10T12:00:00Z'),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', null, 'requested', '2026-09-17T12:00:00Z');
`;

try {
  await run('docker', ['run', '--rm', '-d', '--name', containerName, '-e', 'POSTGRES_PASSWORD=postgres', '-e', `POSTGRES_DB=${database}`, 'postgres:16-alpine']);
  await waitForPostgres();
  await runSql(await readFile(fixturePath, 'utf8'));
  await runSql(await readFile(migrationPath, 'utf8'));
  await runSql(seedSql);

  const queued = await runSql(`select public.queue_automation_notifications(null, '${asOf}');`, { tuplesOnly: true });
  assert.equal(queued, '4', 'Expected one job for each documented automation path.');

  const kinds = rows(await runSql('select kind, count(*) from public.automation_notification_outbox group by kind order by kind;', { tuplesOnly: true }));
  assert.deepEqual(kinds, [
    ['APPOINTMENT_24H', '1'],
    ['CLINICIAN_PRIORITY_DIGEST', '1'],
    ['DEIC_REFERRAL', '1'],
    ['FOLLOW_UP', '1'],
  ]);

  // Queue rules are evaluated at a fixed instant; make the resulting jobs due
  // for the claim test without coupling it to the host clock.
  await runSql("update public.automation_notification_outbox set scheduled_for = now() - interval '1 minute';");
  const claimed = rows(await runSql('select recipient_email, subject from public.claim_automation_notifications(null, 50) order by recipient_email;', { tuplesOnly: true }));
  assert.equal(claimed.length, 4, 'Expected all queued jobs to be claimable once.');
  assert.deepEqual(claimed.map(([email]) => email), [
    'appointment.parent@example.test',
    'clinician@example.test',
    'red.parent@example.test',
    'yellow.parent@example.test',
  ]);

  const marked = await runSql("select public.mark_automation_notification_sent((select id from public.automation_notification_outbox where kind = 'DEIC_REFERRAL'));", { tuplesOnly: true });
  assert.equal(marked, 't', 'A claimed notification must transition to sent.');

  const requeued = await runSql(`select public.queue_automation_notifications(null, '${asOf}');`, { tuplesOnly: true });
  assert.equal(requeued, '0', 'Running the queue again must not duplicate a delivery.');
  const statuses = rows(await runSql('select status, count(*) from public.automation_notification_outbox group by status order by status;', { tuplesOnly: true }));
  assert.deepEqual(statuses, [['processing', '3'], ['sent', '1']]);

  console.log('Validated reminder outbox queueing, claiming, delivery marking, and idempotency against PostgreSQL.');
} finally {
  await run('docker', ['rm', '-f', containerName]).catch(() => undefined);
}
