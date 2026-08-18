import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Drift",
  description: "Download Drift for macOS or Windows from a pixel-art desert title screen.",
  openGraph: {
    title: "Drift",
    description: "A polished pixel-art desert title screen for Drift downloads.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Drift",
    description: "A polished pixel-art desert title screen for Drift downloads.",
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
