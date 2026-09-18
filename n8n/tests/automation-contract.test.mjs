import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const testDirectory = dirname(fileURLToPath(import.meta.url));
const rootDirectory = join(testDirectory, '..', '..');
const workflowDirectory = join(rootDirectory, 'n8n', 'workflows');
const migrationPath = join(rootDirectory, 'supabase', 'migrations', '202609190002_automation_outbox.sql');

test('automation workflows cover the parent, appointment, and clinician paths', async () => {
  const workflows = await Promise.all(
    (await readdir(workflowDirectory))
      .filter((file) => file.endsWith('.json'))
      .map(async (file) => JSON.parse(await readFile(join(workflowDirectory, file), 'utf8'))),
  );
  const workflowText = workflows.map((workflow) => JSON.stringify(workflow)).join('\n');

  for (const kind of ['DEIC_REFERRAL', 'FOLLOW_UP', 'APPOINTMENT_24H', 'CLINICIAN_PRIORITY_DIGEST']) {
    assert.match(workflowText, new RegExp(kind));
  }
  assert.ok(workflows.every((workflow) => workflow.active === false));
  assert.ok(workflows.every((workflow) => workflow.nodes.some((node) => node.type === 'n8n-nodes-base.manualTrigger')));
});

test('outbox migration enforces idempotent service-only delivery', async () => {
  const migration = await readFile(migrationPath, 'utf8');

  assert.match(migration, /dedupe_key text not null unique/);
  assert.match(migration, /'deic:%s:%s:%s'/);
  assert.match(migration, /'follow-up:%s:%s:%s'/);
  assert.match(migration, /for update of outbox skip locked/);
  assert.match(migration, /status = 'processing'/);
  assert.match(migration, /interval '30 minutes'/);
  assert.match(migration, /grant execute on function public\.claim_automation_notifications\(text\[\], integer\) to service_role/);
  assert.doesNotMatch(migration, /grant execute on function public\.claim_automation_notifications\(text\[\], integer\) to authenticated/);
  assert.match(migration, /join auth\.users recipient/);
});
