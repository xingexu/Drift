import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Drift — Make focus feel like progress",
  description: "A private desktop focus tool that turns attention into a living desert journey.",
  openGraph: {
    title: "Drift — Make focus feel like progress",
    description: "A private desktop focus tool that turns attention into a living desert journey.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Drift — Make focus feel like progress",
    description: "A private desktop focus tool that turns attention into a living desert journey.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
