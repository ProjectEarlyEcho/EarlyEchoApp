import { ChatWorkspace } from "@/components/chat-workspace";
import { getConversations } from "@/lib/conversation-data";

export default async function ParentMessagesPage() {
  const conversations = await getConversations();
  return <div className="stack"><section><p className="eyebrow">Care team</p><h1>Messages</h1><p className="lede">Use this space for non-urgent questions about screening follow-up and appointments.</p></section><ChatWorkspace conversations={conversations} counterpartLabel="Clinician" /></div>;
}
