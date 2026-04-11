import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import { ThemeProvider } from "@/components/theme-provider";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800"],
  variable: "--font-inter",
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  weight: ["400", "500"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Drift — Know where your time goes",
  description:
    "Drift tracks your browsing sessions and shows exactly when you lose focus. No judgment, just clarity.",
  openGraph: {
    title: "Drift — Know where your time goes",
    description:
      "Track your browsing sessions and see exactly when you lose focus.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Drift — Know where your time goes",
    description:
      "Track your browsing sessions and see exactly when you lose focus.",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      className={`${inter.variable} ${jetbrainsMono.variable}`}
      suppressHydrationWarning
    >
      <body>
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
