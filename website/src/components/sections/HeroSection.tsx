"use client";

import { useI18n } from "@/i18n";
import { useTypewriter } from "@/hooks/useTypewriter";
import Image from "next/image";
import { Apple } from "lucide-react";

function WindowsIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M0 3.449L9.75 2.1v9.45H0V3.449zm0 16.902l9.75-1.35V9.6H0v10.751zM10.8 2.025L24 0v11.4H10.8V2.025zm0 21.375L24 24V12.6H10.8v10.8z" />
    </svg>
  );
}

export default function HeroSection() {
  const { t } = useI18n();
  const taglines = t.hero.taglines as string[];
  const typedText = useTypewriter(taglines);

  const downloadUrl = process.env.NEXT_PUBLIC_DOWNLOAD_URL ?? "";
  const downloadUrlMac = process.env.NEXT_PUBLIC_DOWNLOAD_URL_MAC ?? "";
  const appVersion = process.env.NEXT_PUBLIC_APP_VERSION ?? "0.8.1";

  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden bg-gradient-to-br from-[#0f172a] via-[#1e293b] to-[#0f172a]">
      {/* Glow circles */}
      <div className="absolute top-1/4 left-1/4 w-[500px] h-[500px] rounded-full bg-blue-500/20 blur-[120px] pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] rounded-full bg-cyan-400/15 blur-[100px] pointer-events-none" />

      <div className="relative z-10 max-w-[1200px] mx-auto px-6 pt-20 pb-16 w-full">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Left text */}
          <div className="text-center lg:text-left">
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-white mb-6 tracking-tight">
              {t.hero.title}
            </h1>

            {/* Typewriter */}
            <div className="h-12 sm:h-14 flex items-center justify-center lg:justify-start mb-6">
              <span className="text-xl sm:text-2xl lg:text-3xl text-cyan-400 font-medium">
                {typedText}
              </span>
              <span className="inline-block w-0.5 h-6 sm:h-7 bg-cyan-400 ml-0.5 animate-pulse" />
            </div>

            <p className="text-base sm:text-lg text-gray-300 leading-relaxed mb-8 max-w-lg mx-auto lg:mx-0">
              {t.hero.description}
            </p>

            {/* CTA Buttons */}
            <div className="flex flex-wrap gap-3 justify-center lg:justify-start">
              <a
                href={downloadUrl}
                className="inline-flex items-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-500 text-white font-semibold rounded-xl text-base transition-all duration-200 shadow-lg shadow-blue-600/25 hover:shadow-blue-500/40 hover:-translate-y-0.5"
              >
                <WindowsIcon className="w-5 h-5" />
                {t.hero.cta_win}
              </a>
              {downloadUrlMac && (
                <a
                  href={downloadUrlMac}
                  className="inline-flex items-center gap-2 px-6 py-3 bg-white/10 hover:bg-white/20 text-white font-semibold rounded-xl text-base border border-white/20 transition-all duration-200 hover:-translate-y-0.5"
                >
                  <Apple className="w-5 h-5" />
                  {t.hero.cta_mac}
                </a>
              )}
            </div>

            {/* Meta info */}
            <div className="mt-8 flex flex-wrap items-center gap-4 text-sm text-gray-400 justify-center lg:justify-start">
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 bg-white/5 rounded-full border border-white/10">
                {appVersion}
              </span>
              <span>{t.hero.requirements}</span>
              <span>
                {t.hero.qq_group}: {t.hero.qq_group_number}
              </span>
            </div>
          </div>

          {/* Right screenshot */}
          <div className="flex justify-center lg:justify-end">
            <div className="relative rounded-2xl overflow-hidden shadow-2xl shadow-black/40 border border-white/10 max-w-[540px]">
              <Image
                src="/images/screenshot.png"
                alt="AgentSphere Screenshot"
                width={1080}
                height={720}
                className="w-full h-auto"
                priority
              />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
