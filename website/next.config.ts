import type { NextConfig } from "next";
import { readFileSync } from "fs";
import path from "path";

interface VersionJson {
  latest_version: string;
  download_url: string;
  platforms?: {
    windows?: { download_url: string };
    macos?: { download_url: string };
  };
}

const versionPath = path.join(process.cwd(), "public/api/version.json");
let versionJson: VersionJson = { latest_version: "0.1.0", download_url: "" };

try {
  versionJson = JSON.parse(readFileSync(versionPath, "utf-8")) as VersionJson;
} catch {
  console.warn("Could not read public/api/version.json, using defaults");
}

const nextConfig: NextConfig = {
  output: "export",
  images: { unoptimized: true },
  env: {
    NEXT_PUBLIC_APP_VERSION: versionJson.latest_version,
    NEXT_PUBLIC_DOWNLOAD_URL: versionJson.download_url,
    NEXT_PUBLIC_DOWNLOAD_URL_WIN:
      versionJson.platforms?.windows?.download_url ?? versionJson.download_url,
    NEXT_PUBLIC_DOWNLOAD_URL_MAC:
      versionJson.platforms?.macos?.download_url ?? "",
  },
};

export default nextConfig;
