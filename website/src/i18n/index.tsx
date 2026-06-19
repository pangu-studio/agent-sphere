"use client";

import { createContext, useContext, useState, useCallback, useEffect, type ReactNode } from "react";
import enUS from "./en-US.json";
import zhCN from "./zh-CN.json";

export type Locale = "en-US" | "zh-CN";
export type Translations = typeof enUS;

const messages: Record<Locale, Translations> = {
  "en-US": enUS,
  "zh-CN": zhCN,
};

const STORAGE_KEY = "tenbox-locale";

function detectLocale(): Locale {
  if (typeof window === "undefined") return "en-US";
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "zh-CN" || stored === "en-US") return stored;
  } catch {
    // localStorage unavailable
  }
  const nav = navigator.language;
  return nav.startsWith("zh") ? "zh-CN" : "en-US";
}

interface I18nContextValue {
  locale: Locale;
  t: Translations;
  setLocale: (locale: Locale) => void;
}

const I18nContext = createContext<I18nContextValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>("en-US");

  useEffect(() => {
    setLocaleState(detectLocale());
  }, []);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      // localStorage unavailable
    }
  }, []);

  return (
    <I18nContext.Provider value={{ locale, t: messages[locale], setLocale }}>
      {children}
    </I18nContext.Provider>
  );
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error("useI18n must be used within I18nProvider");
  return ctx;
}
