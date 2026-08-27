import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Drift",
  openGraph: {
    title: "Drift",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Drift",
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
