"use client";

import { useI18n } from "@/i18n";
import { Shield, Zap, Monitor, Cpu, Layers, Globe } from "lucide-react";
import type { LucideIcon } from "lucide-react";

interface FeatureCardData {
  key: string;
  icon: LucideIcon;
}

const features: FeatureCardData[] = [
  { key: "security", icon: Shield },
  { key: "oneclick", icon: Zap },
  { key: "gui", icon: Monitor },
  { key: "native", icon: Cpu },
  { key: "virtio", icon: Layers },
  { key: "network", icon: Globe },
];

export default function FeaturesSection() {
  const { t } = useI18n();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const ft = (t as any).features;

  return (
    <section id="features" className="py-24 bg-white">
      <div className="max-w-[1200px] mx-auto px-6">
        <h2 className="text-4xl font-bold text-center text-[#1e293b] mb-4">
          {ft.title}
        </h2>
        <p className="text-center text-[#64748b] text-lg mb-16 max-w-2xl mx-auto">
          {ft.subtitle ?? ""}
        </p>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map(({ key, icon: Icon }) => {
            const item = ft[key] as { title: string; desc: string };
            return (
              <div
                key={key}
                className="group relative bg-white rounded-xl p-6 ring-1 ring-gray-200 hover:ring-blue-200 hover:shadow-lg hover:shadow-blue-500/5 transition-all duration-300 hover:-translate-y-1"
              >
                <div className="w-12 h-12 rounded-lg bg-blue-50 flex items-center justify-center mb-4 group-hover:bg-blue-100 transition-colors">
                  <Icon className="w-6 h-6 text-blue-600" />
                </div>
                <h3 className="text-lg font-semibold text-[#1e293b] mb-2">
                  {item.title}
                </h3>
                <p className="text-[#64748b] text-sm leading-relaxed">
                  {item.desc}
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
