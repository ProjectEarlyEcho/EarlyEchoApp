"use client";

import { FormEvent, useEffect, useState } from "react";

import type { Conversation } from "@/lib/conversation-data";
import { createClient } from "@/lib/supabase/client";

type Message = { id: string; sender_id: string; body: string; created_at: string };

export function ChatWorkspace({ conversations, counterpartLabel }: { conversations: Conversation[]; counterpartLabel: string }) {
  const [activeId, setActiveId] = useState(conversations[0]?.id ?? "");
  const [messagesByConversation, setMessagesByConversation] = useState<Record<string, Message[]>>({});
  const [viewerId, setViewerId] = useState("");
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const active = conversations.find((conversation) => conversation.id === activeId);
  const messages = messagesByConversation[activeId] ?? [];

  useEffect(() => {
    const supabase = createClient();
    void supabase.auth.getUser().then(({ data }) => setViewerId(data.user?.id ?? ""));
  }, []);

  useEffect(() => {
    if (!activeId) return;
    const supabase = createClient();
    void supabase.from("messages").select("id, sender_id, body, created_at").eq("conversation_id", activeId).order("created_at").then(({ data, error: queryError }) => {
      if (queryError) setError(queryError.message);
      else {
        setError(null);
        setMessagesByConversation((current) => ({ ...current, [activeId]: (data ?? []) as Message[] }));
      }
    });
    const channel = supabase.channel(`conversation:${activeId}`).on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${activeId}` }, (payload) => {
      setMessagesByConversation((current) => {
        const existing = current[activeId] ?? [];
        if (existing.some((message) => message.id === payload.new.id)) return current;
        return { ...current, [activeId]: [...existing, payload.new as Message] };
      });
    }).subscribe();
    return () => { void supabase.removeChannel(channel); };
  }, [activeId]);

  async function send(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const body = draft.trim();
    if (!body || !activeId) return;
    setDraft("");
    const { error: sendError } = await createClient().from("messages").insert({ conversation_id: activeId, body });
    if (sendError) setError(sendError.message);
  }

  if (!conversations.length) return <div className="card empty"><div className="empty-icon" aria-hidden>✉</div><h3>No messages yet</h3><p className="muted">A secure conversation becomes available when a clinician is assigned to a child.</p></div>;
  return <section className="chat card"><aside className="chat-list"><div className="chat-list-title">Conversations</div><div>{conversations.map((conversation) => <button className={`conversation${conversation.id === activeId ? " active" : ""}`} key={conversation.id} onClick={() => setActiveId(conversation.id)} type="button"><strong>{conversation.childName}</strong><span>{counterpartLabel} care conversation</span></button>)}</div></aside><div className="chat-main"><header className="chat-header"><strong>{active?.childName}</strong><p className="muted" style={{ margin: "4px 0 0", fontSize: 12 }}>Messages are visible only to this child&apos;s family and care team.</p></header><div className="messages">{messages.map((message) => <div className={`message${message.sender_id === viewerId ? " mine" : ""}`} key={message.id}>{message.body}<time>{new Intl.DateTimeFormat("en-IN", { hour: "numeric", minute: "2-digit" }).format(new Date(message.created_at))}</time></div>)}{error ? <p className="form-message error">{error}</p> : null}</div><form className="chat-compose" onSubmit={send}><input aria-label="Message" maxLength={2000} onChange={(event) => setDraft(event.target.value)} placeholder="Write a message…" value={draft} /><button className="button" type="submit">Send</button></form></div></section>;
}
