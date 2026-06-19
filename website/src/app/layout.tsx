import type { Metadata } from "next";
import { Geist_Mono } from "next/font/google";
import "./globals.css";
import { I18nProvider } from "@/i18n";

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "AgentSphere — Tiny, Easy, Native Agent VM",
  description:
    "AI Agents run in an isolated computer — they can only see files you explicitly allow, so your privacy and data stay protected. Supports OpenClaw, QwenPaw and more. One click to create, as easy as installing an app.",
  icons: {
    icon: "/favicon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={`${geistMono.variable}`}>
      <body className="min-h-full flex flex-col">
        <I18nProvider>{children}</I18nProvider>
      </body>
    </html>
  );
}
