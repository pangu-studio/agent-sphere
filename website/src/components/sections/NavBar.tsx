"use client";
import { useState, useEffect } from "react";
import { useI18n } from "@/i18n";
import Image from "next/image";
function GithubIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" />
    </svg>
  );
}

export default function NavBar() {
  const { t, locale, setLocale } = useI18n();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 50);
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const toggleLocale = () => {
    setLocale(locale === "zh-CN" ? "en-US" : "zh-CN");
  };

  return (
    <nav
      className={`fixed top-0 left-0 right-0 z-50 h-16 flex items-center transition-all duration-300 ${
        scrolled
          ? "bg-white/80 backdrop-blur-md border-b border-gray-200/50 shadow-sm"
          : "bg-transparent"
      }`}
    >
      <div className="max-w-[1200px] mx-auto w-full px-6 flex items-center justify-between">
        {/* Brand */}
        <a href="/" className="flex items-center gap-2.5 no-underline">
          <Image
            src="/logo.png"
            alt="AgentSphere"
            width={32}
            height={32}
            className="w-8 h-8"
          />
          <span
            className={`text-lg font-semibold transition-colors ${
              scrolled ? "text-[#1e293b]" : "text-white"
            }`}
          >
            AgentSphere
          </span>
        </a>

        {/* Links */}
        <div className="flex items-center gap-1">
<a
            href="https://github.com/pangu-studio/agent-sphere"
            target="_blank"
            rel="noopener noreferrer"
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
              scrolled
                ? "text-[#64748b] hover:text-[#1e293b] hover:bg-gray-100"
                : "text-white/80 hover:text-white hover:bg-white/10"
            }`}
          >
            <GithubIcon className="w-4 h-4" />
            <span className="hidden sm:inline">{t.nav.github}</span>
          </a>
          <button
            onClick={toggleLocale}
            className={`ml-1 px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors ${
              scrolled
                ? "border-gray-200 text-[#64748b] hover:text-[#1e293b] hover:bg-gray-100"
                : "border-white/20 text-white/80 hover:text-white hover:bg-white/10"
            }`}
          >
            {locale === "zh-CN" ? "EN" : "中文"}
          </button>
        </div>
      </div>
    </nav>
  );
}
