import { ChatWorkspace } from "@/components/chat-workspace";
import { getConversations } from "@/lib/conversation-data";

export default async function ClinicianMessagesPage() {
  const conversations = await getConversations();
  return <div className="stack"><section><p className="eyebrow">Family communication</p><h1>Messages</h1><p className="lede">Use secure messages for non-urgent care coordination. Do not use chat for emergencies or to record formal clinical notes.</p></section><ChatWorkspace conversations={conversations} counterpartLabel="Family" /></div>;
}
