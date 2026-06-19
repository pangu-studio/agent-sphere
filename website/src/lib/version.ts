import { promises as fs } from "fs";
import path from "path";

export interface VersionInfo {
  latest_version: string;
  download_url: string;
  platforms: {
    windows?: { download_url: string };
    macos?: { download_url: string };
  };
}

let cached: VersionInfo | null = null;

export async function getVersionInfo(): Promise<VersionInfo> {
  if (cached) return cached;
  const filePath = path.join(process.cwd(), "public/api/version.json");
  const raw = await fs.readFile(filePath, "utf-8");
  cached = JSON.parse(raw) as VersionInfo;
  return cached;
}

export function getAppVersion(): string {
  // Fallback for client-side; real value injected at build time or via API
  return process.env.NEXT_PUBLIC_APP_VERSION ?? "0.8.1";
}

export function getDownloadUrl(): string {
  return process.env.NEXT_PUBLIC_DOWNLOAD_URL ?? "";
}

export function getDownloadUrlWin(): string {
  return process.env.NEXT_PUBLIC_DOWNLOAD_URL_WIN ?? process.env.NEXT_PUBLIC_DOWNLOAD_URL ?? "";
}

export function getDownloadUrlMac(): string {
  return process.env.NEXT_PUBLIC_DOWNLOAD_URL_MAC ?? "";
}
