import type { Metadata } from "next";

import "./globals.css";

export const metadata: Metadata = {
  title: "EarlyEcho Care Portal",
  description: "Secure screening summaries, care coordination, and family-clinician communication.",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
