import { createClient } from "@supabase/supabase-js";

const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceRoleKey) {
  throw new Error(
    "Set SUPABASE_URL (or NEXT_PUBLIC_SUPABASE_URL) and SUPABASE_SERVICE_ROLE_KEY before running this development seed.",
  );
}

const admin = createClient(url, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const password = "EarlyEchoDemo1!";

const users = [
  { email: "maya.parent@example.test", displayName: "Maya Nair", role: "parent" },
  { email: "rohan.parent@example.test", displayName: "Rohan Menon", role: "parent" },
  { email: "anaya.clinician@example.test", displayName: "Dr Anaya Thomas", role: "clinician" },
  { email: "vivek.clinician@example.test", displayName: "Dr Vivek Shah", role: "clinician" },
];

const ids = {};

function check(error, label) {
  if (error) throw new Error(`${label}: ${error.message}`);
}

async function ensureUser(user) {
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: user.email,
    password,
    email_confirm: true,
    user_metadata: { display_name: user.displayName },
  });

  if (!createError) return created.user.id;
  if (!createError.message.toLowerCase().includes("already")) {
    throw new Error(`Create ${user.email}: ${createError.message}`);
  }

  const { data: listed, error: listError } = await admin.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  check(listError, "Look up existing demo users");
  const existing = listed.users.find((candidate) => candidate.email === user.email);
  if (!existing) throw new Error(`Could not find existing demo user ${user.email}.`);
  return existing.id;
}

for (const user of users) {
  ids[user.email] = await ensureUser(user);
}

const maya = ids["maya.parent@example.test"];
const rohan = ids["rohan.parent@example.test"];
const anaya = ids["anaya.clinician@example.test"];
const vivek = ids["vivek.clinician@example.test"];

const { error: profileError } = await admin.from("profiles").upsert(
  users.map((user) => ({ id: ids[user.email], display_name: user.displayName, role: user.role })),
  { onConflict: "id" },
);
check(profileError, "Seed profiles");

const children = {
  meera: "17000000-0000-4000-8000-000000000001",
  ayaan: "17000000-0000-4000-8000-000000000002",
  tara: "17000000-0000-4000-8000-000000000003",
};

const { error: childError } = await admin.from("children").upsert([
  { id: children.meera, display_name: "Meera", birth_date: "2023-04-09" },
  { id: children.ayaan, display_name: "Ayaan", birth_date: "2024-05-17" },
  { id: children.tara, display_name: "Tara", birth_date: "2025-02-17" },
]);
check(childError, "Seed children");

const { error: guardianError } = await admin.from("child_guardians").upsert([
  { child_id: children.meera, parent_id: maya },
  { child_id: children.ayaan, parent_id: rohan },
  { child_id: children.tara, parent_id: maya },
], { onConflict: "child_id,parent_id" });
check(guardianError, "Seed guardians");

const { error: careTeamError } = await admin.from("care_team").upsert([
  { child_id: children.meera, clinician_id: anaya },
  { child_id: children.ayaan, clinician_id: anaya },
  { child_id: children.tara, clinician_id: vivek },
], { onConflict: "child_id,clinician_id" });
check(careTeamError, "Seed care-team assignments");

const { error: screeningError } = await admin.from("screening_sessions").upsert([
  {
    id: "27000000-0000-4000-8000-000000000001",
    child_id: children.meera,
    created_by: anaya,
    created_at: "2026-06-18T09:30:00Z",
    analysis_status: "COMPLETE",
    risk_level: "yellow",
    child_age_months: 38,
    vttl_ms: 1110,
    cvr_ratio: 0.18,
    pfv_std: 19.4,
    quality_reasons: [],
    audio_source: "UNPROCESSED",
  },
  {
    id: "27000000-0000-4000-8000-000000000002",
    child_id: children.meera,
    created_by: anaya,
    created_at: "2026-09-12T09:30:00Z",
    analysis_status: "COMPLETE",
    risk_level: "red",
    child_age_months: 41,
    vttl_ms: 1350,
    cvr_ratio: 0.1,
    pfv_std: 13.7,
    quality_reasons: [],
    audio_source: "UNPROCESSED",
  },
  {
    id: "27000000-0000-4000-8000-000000000003",
    child_id: children.ayaan,
    created_by: anaya,
    created_at: "2026-09-09T10:15:00Z",
    analysis_status: "COMPLETE",
    risk_level: "yellow",
    child_age_months: 28,
    vttl_ms: 1180,
    cvr_ratio: 0.17,
    pfv_std: 21.3,
    quality_reasons: [],
    audio_source: "UNPROCESSED",
  },
  {
    id: "27000000-0000-4000-8000-000000000004",
    child_id: children.tara,
    created_by: vivek,
    created_at: "2026-09-14T11:00:00Z",
    analysis_status: "COMPLETE",
    risk_level: "green",
    child_age_months: 19,
    vttl_ms: 680,
    cvr_ratio: 0.16,
    pfv_std: 22.1,
    quality_reasons: [],
    audio_source: "UNPROCESSED",
  },
  {
    id: "27000000-0000-4000-8000-000000000005",
    child_id: children.tara,
    created_by: vivek,
    created_at: "2026-09-16T11:00:00Z",
    analysis_status: "INCOMPLETE",
    risk_level: null,
    child_age_months: 19,
    vttl_ms: null,
    cvr_ratio: null,
    pfv_std: null,
    quality_reasons: ["Background noise was too high."],
    audio_source: "VOICE_RECOGNITION",
  },
]);
check(screeningError, "Seed screening sessions");

const { error: appointmentError } = await admin.from("appointments").upsert([
  {
    id: "37000000-0000-4000-8000-000000000001",
    child_id: children.meera,
    parent_id: maya,
    clinician_id: anaya,
    requested_for: "2026-09-22T09:30:00Z",
    starts_at: null,
    status: "requested",
    reason: "Discuss the latest screening summary and next steps.",
  },
  {
    id: "37000000-0000-4000-8000-000000000002",
    child_id: children.ayaan,
    parent_id: rohan,
    clinician_id: anaya,
    requested_for: "2026-09-24T14:00:00Z",
    starts_at: "2026-09-24T14:00:00Z",
    status: "confirmed",
    reason: "Routine follow-up after a yellow screening result.",
  },
]);
check(appointmentError, "Seed appointments");

async function conversationFor(childId, parentId, clinicianId) {
  const { data: existing, error: findError } = await admin
    .from("conversations")
    .select("id")
    .eq("child_id", childId)
    .eq("parent_id", parentId)
    .eq("clinician_id", clinicianId)
    .maybeSingle();
  check(findError, "Find seeded conversation");
  if (existing) return existing.id;

  const { data: created, error: createError } = await admin
    .from("conversations")
    .insert({ child_id: childId, parent_id: parentId, clinician_id: clinicianId })
    .select("id")
    .single();
  check(createError, "Create seeded conversation");
  return created.id;
}

const meeraConversation = await conversationFor(children.meera, maya, anaya);
const ayaanConversation = await conversationFor(children.ayaan, rohan, anaya);

const { error: messageError } = await admin.from("messages").upsert([
  {
    id: "47000000-0000-4000-8000-000000000001",
    conversation_id: meeraConversation,
    sender_id: anaya,
    body: "I have reviewed the latest screening summary. Please request a follow-up appointment so we can discuss the next step together.",
    created_at: "2026-09-13T08:45:00Z",
  },
  {
    id: "47000000-0000-4000-8000-000000000002",
    conversation_id: meeraConversation,
    sender_id: maya,
    body: "Thank you. I have sent an appointment request for next week.",
    created_at: "2026-09-13T10:05:00Z",
  },
  {
    id: "47000000-0000-4000-8000-000000000003",
    conversation_id: ayaanConversation,
    sender_id: rohan,
    body: "Thank you for confirming the follow-up visit.",
    created_at: "2026-09-18T07:30:00Z",
  },
]);
check(messageError, "Seed messages");

const { error: noteError } = await admin.from("clinical_notes").upsert({
  id: "57000000-0000-4000-8000-000000000001",
  child_id: children.meera,
  clinician_id: anaya,
  body: "Demo note: review the screening trend during the follow-up visit. This note is visible only to the assigned clinician.",
  created_at: "2026-09-13T08:50:00Z",
});
check(noteError, "Seed clinician-only note");

console.log("Demo care portal data is ready.");
console.log("Parent accounts: maya.parent@example.test, rohan.parent@example.test");
console.log("Clinician accounts: anaya.clinician@example.test, vivek.clinician@example.test");
console.log(`Demo password for every account: ${password}`);
