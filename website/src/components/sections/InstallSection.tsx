"use client";

import { useI18n } from "@/i18n";
import { Apple, ArrowRight } from "lucide-react";

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

export default function InstallSection() {
  const { t } = useI18n();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const it = (t as any).install;

  const downloadUrlWin =
    process.env.NEXT_PUBLIC_DOWNLOAD_URL_WIN ??
    process.env.NEXT_PUBLIC_DOWNLOAD_URL ??
    "";
  const downloadUrlMac = process.env.NEXT_PUBLIC_DOWNLOAD_URL_MAC ?? "";

  return (
    <section id="install" className="py-24 bg-[#f8fafc]">
      <div className="max-w-[1200px] mx-auto px-6">
        <h2 className="text-4xl font-bold text-center text-[#1e293b] mb-4">
          {it.title}
        </h2>
        <p className="text-center text-[#64748b] text-lg mb-16">
          {it.subtitle}
        </p>

        <div className="max-w-3xl mx-auto grid sm:grid-cols-2 gap-6">
          {/* Windows */}
          <div className="bg-white rounded-xl ring-1 ring-gray-200 p-6 shadow-sm hover:shadow-md transition-shadow">
            <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center mb-4">
              <WindowsIcon className="w-5 h-5 text-blue-600" />
            </div>
            <h3 className="text-lg font-semibold text-[#1e293b] mb-2">
              {it.windows.title}
            </h3>
            <p className="text-[#64748b] text-sm mb-4">{it.windows.desc}</p>
            <a
              href={downloadUrlWin}
              className="inline-flex items-center gap-1.5 text-blue-600 hover:text-blue-700 font-medium text-sm transition-colors"
            >
              {it.windows.cta}
              <ArrowRight className="w-4 h-4" />
            </a>
          </div>

          {/* macOS */}
          {downloadUrlMac && (
            <div className="bg-white rounded-xl ring-1 ring-gray-200 p-6 shadow-sm hover:shadow-md transition-shadow">
              <div className="w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center mb-4">
                <Apple className="w-5 h-5 text-blue-600" />
              </div>
              <h3 className="text-lg font-semibold text-[#1e293b] mb-2">
                {it.macos.title}
              </h3>
              <p className="text-[#64748b] text-sm mb-4">{it.macos.desc}</p>
              <a
                href={downloadUrlMac}
                className="inline-flex items-center gap-1.5 text-blue-600 hover:text-blue-700 font-medium text-sm transition-colors"
              >
                {it.macos.cta}
                <ArrowRight className="w-4 h-4" />
              </a>
            </div>
          )}
        </div>

        {/* macOS not available yet hint */}
        {!downloadUrlMac && (
          <p className="text-center text-[#94a3b8] text-sm mt-6">
            macOS version coming soon.
          </p>
        )}
      </div>
    </section>
  );
}
