import { readFile, readdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const automationDirectory = join(scriptDirectory, '..');
const workflowDirectory = join(automationDirectory, 'workflows');

const expectedWorkflows = new Map([
  [
    'parent-follow-up-and-referral-reminders.json',
    {
      kinds: ['DEIC_REFERRAL', 'FOLLOW_UP'],
      schedule: '0 0 9 * * 1',
      emailNode: 'Send parent reminder',
      claimNode: 'Claim parent reminders',
    },
  ],
  [
    'appointment-reminders.json',
    {
      kinds: ['APPOINTMENT_24H'],
      schedule: '0 */15 * * * *',
      emailNode: 'Send appointment reminder',
      claimNode: 'Claim appointment reminders',
    },
  ],
  [
    'clinician-priority-digest.json',
    {
      kinds: ['CLINICIAN_PRIORITY_DIGEST'],
      schedule: '0 30 17 * * 1-5',
      emailNode: 'Send clinician digest',
      claimNode: 'Claim clinician digest',
    },
  ],
]);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function jsonString(value) {
  return JSON.stringify(value ?? {});
}

function firstInputNodeNames(workflow) {
  const connected = new Set();
  for (const connection of Object.values(workflow.connections ?? {})) {
    for (const branch of connection.main ?? []) {
      for (const edge of branch ?? []) connected.add(edge.node);
    }
  }
  return workflow.nodes.filter((node) => !connected.has(node.name)).map((node) => node.name);
}

const files = (await readdir(workflowDirectory)).filter((file) => file.endsWith('.json')).sort();
assert(files.length === expectedWorkflows.size, 'Expected exactly the three documented automation workflows.');
assert(files.every((file) => expectedWorkflows.has(file)), 'Workflow directory contains an undocumented workflow.');

const workflowNames = new Set();
for (const file of files) {
  const expected = expectedWorkflows.get(file);
  const workflow = JSON.parse(await readFile(join(workflowDirectory, file), 'utf8'));
  const nodesByName = new Map(workflow.nodes.map((node) => [node.name, node]));
  const nodesByType = new Map();
  for (const node of workflow.nodes) {
    nodesByType.set(node.type, [...(nodesByType.get(node.type) ?? []), node]);
  }

  assert(typeof workflow.name === 'string' && workflow.name.startsWith('EarlyEcho'), `${file} must have a product workflow name.`);
  assert(typeof workflow.id === 'string' && workflow.id.length > 0, `${file} must have an importable n8n workflow ID.`);
  assert(!workflowNames.has(workflow.name), `${file} has a duplicate workflow name.`);
  workflowNames.add(workflow.name);
  assert(workflow.active === false, `${file} must be imported inactive so delivery is never enabled accidentally.`);
  assert(nodesByType.get('n8n-nodes-base.manualTrigger')?.length === 1, `${file} must include one Manual Trigger for safe testing.`);
  assert(nodesByType.get('n8n-nodes-base.scheduleTrigger')?.length === 1, `${file} must include one Schedule Trigger.`);
  assert(firstInputNodeNames(workflow).length === 2, `${file} must have exactly its schedule and manual test entry points.`);

  const schedule = nodesByType.get('n8n-nodes-base.scheduleTrigger')[0];
  assert(
    schedule.parameters?.rule?.interval?.[0]?.expression === expected.schedule,
    `${file} schedule does not match its documented cadence.`,
  );

  const httpNodes = nodesByType.get('n8n-nodes-base.httpRequest') ?? [];
  assert(httpNodes.length === 3, `${file} must queue, claim, and mark each delivery.`);
  const queueNode = httpNodes.find((node) => node.name.startsWith('Queue '));
  const claimNode = nodesByName.get(expected.claimNode);
  const markNode = httpNodes.find((node) => node.name.startsWith('Mark '));
  assert(queueNode && claimNode && markNode, `${file} has an incomplete outbox delivery chain.`);

  const queueBody = queueNode.parameters?.jsonBody ?? '';
  const claimBody = claimNode.parameters?.jsonBody ?? '';
  for (const kind of expected.kinds) {
    assert(queueBody.includes(kind) && claimBody.includes(kind), `${file} does not consistently handle ${kind}.`);
  }
  for (const node of httpNodes) {
    const serialized = jsonString(node.parameters);
    assert(serialized.includes('$env.SUPABASE_URL'), `${file} must read the Supabase URL from the environment.`);
    assert(serialized.includes('$env.SUPABASE_SERVICE_ROLE_KEY'), `${file} must read the service credential from the environment.`);
    assert(!serialized.includes('your-project.supabase.co'), `${file} contains a placeholder Supabase host.`);
  }
  assert(
    (markNode.parameters?.jsonBody ?? '').includes(`$('${expected.claimNode}').item.json.notification_id`),
    `${file} must mark the notification claimed for the same delivery item.`,
  );

  const emailNode = nodesByName.get(expected.emailNode);
  assert(emailNode?.type === 'n8n-nodes-base.emailSend', `${file} is missing its email delivery node.`);
  assert(emailNode.parameters?.resource === 'email' && emailNode.parameters?.operation === 'send', `${file} must use the email send operation.`);
  assert(emailNode.parameters?.fromEmail.includes('$env.REMINDER_FROM_EMAIL'), `${file} must read its sender from the environment.`);
  assert(emailNode.parameters?.toEmail.includes('$json.recipient_email'), `${file} must use the claimed recipient only.`);
}

console.log(`Validated ${files.length} inactive n8n workflows.`);
