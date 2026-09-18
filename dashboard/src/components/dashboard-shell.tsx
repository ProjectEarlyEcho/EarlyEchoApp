"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";

import type { AppRole, Viewer } from "@/lib/auth";
import { SignOutButton } from "@/components/sign-out-button";

const navigation: Record<Exclude<AppRole, "admin">, { href: string; label: string; icon: string }[]> = {
  parent: [
    { href: "/parent", label: "My family", icon: "⌂" },
    { href: "/parent/appointments", label: "Appointments", icon: "◷" },
    { href: "/parent/messages", label: "Messages", icon: "✉" },
  ],
  clinician: [
    { href: "/clinician", label: "Overview", icon: "⌂" },
    { href: "/clinician/families", label: "Families", icon: "◉" },
    { href: "/clinician/appointments", label: "Appointments", icon: "◷" },
    { href: "/clinician/messages", label: "Messages", icon: "✉" },
  ],
};

type Props = { viewer: Viewer; children: ReactNode };

export function DashboardShell({ viewer, children }: Props) {
  const pathname = usePathname();
  const role = viewer.role === "parent" ? "parent" : "clinician";
  const items = navigation[role];
  const initial = (viewer.displayName?.trim().charAt(0) || "E").toUpperCase();

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Link className="brand" href={role === "parent" ? "/parent" : "/clinician"}>
          <span className="brand-mark">E</span>
          <span>
            <span className="brand-name">EarlyEcho</span>
            <span className="brand-subtitle">{role === "parent" ? "Family care portal" : "Clinical workspace"}</span>
          </span>
        </Link>
        <nav className="nav" aria-label="Main navigation">
          {items.map((item) => {
            const active = item.href === `/${role}` ? pathname === item.href : pathname.startsWith(item.href);
            return (
              <Link className={`nav-link${active ? " active" : ""}`} href={item.href} key={item.href}>
                <span aria-hidden className="nav-icon">{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
        </nav>
        <p className="sidebar-footer">Screening support, not a diagnosis.</p>
      </aside>
      <main className="page">
        <header className="topbar">
          <div />
          <div className="user-menu">
            <span className="avatar" aria-hidden>{initial}</span>
            <span className="user-copy">{viewer.displayName || "EarlyEcho user"}<span>{role === "parent" ? "Parent account" : "Clinician account"}</span></span>
            <SignOutButton />
          </div>
        </header>
        {children}
      </main>
    </div>
  );
}
