import { createClient } from "@/lib/supabase/server";

export type Conversation = {
  id: string;
  childName: string;
  updatedAt: string;
};

export async function getConversations(): Promise<Conversation[]> {
  const supabase = await createClient();
  if (!supabase) return [];

  const { data } = await supabase
    .from("conversations")
    .select("id, updated_at, children(display_name)")
    .order("updated_at", { ascending: false });

  return (data ?? []).map((conversation) => {
    const child = Array.isArray(conversation.children)
      ? conversation.children[0]
      : conversation.children;
    return {
      id: conversation.id as string,
      childName: (child?.display_name as string | undefined) ?? "Child",
      updatedAt: conversation.updated_at as string,
    };
  });
}
