import type { ReactNode } from "react";

export function EmptyState({ title, detail, action }: { title: string; detail: string; action?: ReactNode }) {
  return <div className="card empty"><div className="empty-icon" aria-hidden>+</div><h3>{title}</h3><p className="muted">{detail}</p>{action}</div>;
}
