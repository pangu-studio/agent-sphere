"use client";

import { useI18n } from "@/i18n";

export default function HowItWorks() {
  const { t } = useI18n();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const h = (t as any).howitworks;

  const steps = [
    { key: "step1", num: 1 },
    { key: "step2", num: 2 },
    { key: "step3", num: 3 },
  ];

  return (
    <section id="how-it-works" className="py-24 bg-white">
      <div className="max-w-[1200px] mx-auto px-6">
        <h2 className="text-4xl font-bold text-center text-[#1e293b] mb-16">
          {h.title}
        </h2>

        <div className="relative max-w-4xl mx-auto">
          {/* Horizontal connector line — spans between circles */}
          <div
            className="hidden md:block absolute top-8 h-0.5 bg-gray-200 rounded-full"
            style={{
              left: "calc(100% / 6 + 32px)",
              right: "calc(100% / 6 + 32px)",
            }}
          />

          {/* Steps */}
          <div className="flex flex-col md:flex-row items-center md:items-start justify-center">
            {steps.map(({ key, num }) => {
              const step = h[key] as { title: string; desc: string };
              return (
                <div
                  key={key}
                  className="flex flex-col items-center text-center px-4 flex-1"
                >
                  <div className="relative z-10 w-16 h-16 rounded-full bg-blue-600 text-white flex items-center justify-center text-2xl font-bold mb-6 shadow-lg shadow-blue-600/25 ring-4 ring-white">
                    {num}
                  </div>
                  <h3 className="text-lg font-semibold text-[#1e293b] mb-3">
                    {step.title}
                  </h3>
                  <p className="text-[#64748b] text-sm leading-relaxed max-w-xs">
                    {step.desc}
                  </p>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}
