"use client";

import { useI18n } from "@/i18n";

export default function FooterSection() {
  const { t } = useI18n();

  return (
    <footer className="py-10 bg-[#f8fafc] border-t border-gray-200">
      <div className="max-w-[1200px] mx-auto px-6 text-center">
        <p className="text-sm text-[#64748b]">{t.footer.copyright}</p>
      </div>
    </footer>
  );
}
