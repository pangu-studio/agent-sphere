<template>
  <section class="install" id="install">
    <div class="container">
      <h2 class="section-title">{{ $t('install.title') }}</h2>
      <p class="section-subtitle">{{ $t('install.subtitle') }}</p>

      <!-- Linux primary card -->
      <div class="install-primary">
        <div class="install-primary-head">
          <div class="install-icon install-icon-linux">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M12.5 2c-.55 0-1.05.4-1.4.9-.35.5-.6 1.2-.6 1.95 0 .35.05.65.13.95-.4.25-.78.6-1.13 1-.55-.13-1.05-.13-1.45 0-.55.18-1 .55-1.3 1-.6.9-.65 2.05-.5 3.05.18 1.05.55 2.05 1 2.95-.5.85-.95 1.75-1.25 2.65-.3.95-.45 1.95-.2 2.85.13.45.35.85.7 1.15.4.35.95.55 1.55.55h7.5c.6 0 1.15-.2 1.55-.55.35-.3.55-.7.7-1.15.25-.9.1-1.9-.2-2.85-.3-.9-.75-1.8-1.25-2.65.45-.9.85-1.9 1-2.95.13-1 .1-2.15-.5-3.05-.3-.45-.75-.85-1.3-1-.4-.13-.9-.13-1.45 0-.35-.4-.73-.75-1.13-1 .08-.3.13-.6.13-.95 0-.75-.25-1.45-.6-1.95-.35-.5-.85-.9-1.4-.9zm0 1.5c.15 0 .35.13.55.45.2.3.35.75.35 1.2 0 .25-.05.5-.1.7-.27-.05-.55-.1-.8-.1s-.53.05-.8.1c-.05-.2-.1-.45-.1-.7 0-.45.15-.9.35-1.2.2-.32.4-.45.55-.45z"/>
            </svg>
          </div>
          <div class="install-primary-titlebox">
            <h3 class="install-primary-title">{{ $t('install.linux.title') }}</h3>
            <p class="install-primary-desc">{{ $t('install.linux.desc') }}</p>
          </div>
        </div>

        <div class="install-cmd">
          <code class="install-cmd-text">{{ linuxCommand }}</code>
          <button class="install-copy" type="button" @click="copyCommand" :aria-label="$t('install.linux.copy')">
            <svg v-if="!copied" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
              <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
            </svg>
            <svg v-else width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <polyline points="20 6 9 17 4 12"/>
            </svg>
            <span>{{ copied ? $t('install.linux.copied') : $t('install.linux.copy') }}</span>
          </button>
        </div>

        <p class="install-footnote">
          {{ $t('install.linux.footnote') }}
          <a href="https://my.tenbox.ai/" target="_blank" rel="noopener noreferrer">
            {{ $t('install.linux.footnote_link') }}
          </a>
          {{ $t('install.linux.footnote_after') }}
        </p>
      </div>

      <!-- Secondary download cards -->
      <div class="install-grid">
        <a :href="downloadUrlWin" class="install-card">
          <div class="install-icon install-icon-win">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M0 3.5L9.75 2v9.4H0V3.5zm0 17l9.75 1.5v-9.4H0v7.9zm10.85 1.65L24 24V12.6H10.85v9.55zM10.85 2v9.4H24V0L10.85 2z"/>
            </svg>
          </div>
          <div class="install-card-body">
            <h3 class="install-card-title">{{ $t('install.windows.title') }}</h3>
            <p class="install-card-desc">{{ $t('install.windows.desc') }}</p>
          </div>
          <span class="install-card-cta">
            {{ $t('install.windows.cta') }}
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <line x1="5" y1="12" x2="19" y2="12"/>
              <polyline points="12 5 19 12 12 19"/>
            </svg>
          </span>
        </a>

        <a v-if="downloadUrlMac" :href="downloadUrlMac" class="install-card">
          <div class="install-icon install-icon-mac">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
          </div>
          <div class="install-card-body">
            <h3 class="install-card-title">{{ $t('install.macos.title') }}</h3>
            <p class="install-card-desc">{{ $t('install.macos.desc') }}</p>
          </div>
          <span class="install-card-cta">
            {{ $t('install.macos.cta') }}
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <line x1="5" y1="12" x2="19" y2="12"/>
              <polyline points="12 5 19 12 12 19"/>
            </svg>
          </span>
        </a>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref } from 'vue'

/* global __APP_DOWNLOAD_URL_WIN__, __APP_DOWNLOAD_URL_MAC__ */
const downloadUrlWin = __APP_DOWNLOAD_URL_WIN__
const downloadUrlMac = __APP_DOWNLOAD_URL_MAC__

const linuxCommand = 'curl -fsSL https://tenbox.ai/install.sh | sudo sh'
const copied = ref(false)

let resetTimer = null

async function copyCommand() {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(linuxCommand)
    } else {
      // Fallback for older browsers / non-https previews.
      const ta = document.createElement('textarea')
      ta.value = linuxCommand
      ta.style.position = 'fixed'
      ta.style.opacity = '0'
      document.body.appendChild(ta)
      ta.select()
      document.execCommand('copy')
      document.body.removeChild(ta)
    }
    copied.value = true
    if (resetTimer) clearTimeout(resetTimer)
    resetTimer = setTimeout(() => {
      copied.value = false
    }, 1800)
  } catch (e) {
    // Silently ignore — user can still select and copy manually.
  }
}
</script>

<style scoped>
.install {
  padding: var(--section-padding);
  background: var(--color-bg-alt);
  scroll-margin-top: var(--nav-height);
}

/* Linux primary card */
.install-primary {
  margin: 48px auto 24px;
  max-width: 880px;
  background: var(--color-card-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  padding: 36px;
  box-shadow: var(--color-card-shadow);
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.install-primary-head {
  display: flex;
  gap: 18px;
  align-items: center;
}

.install-primary-titlebox {
  flex: 1;
  min-width: 0;
}

.install-primary-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: 6px;
}

.install-primary-desc {
  font-size: 0.95rem;
  line-height: 1.6;
  color: var(--color-text-light);
}

.install-cmd {
  display: flex;
  align-items: center;
  gap: 12px;
  background: #0f172a;
  border-radius: var(--border-radius-sm);
  padding: 16px 20px;
  overflow: hidden;
}

.install-cmd-text {
  flex: 1;
  font-family: var(--font-mono);
  font-size: 0.95rem;
  color: #e2e8f0;
  white-space: nowrap;
  overflow-x: auto;
  user-select: all;
}

.install-cmd-text::before {
  content: '$ ';
  color: #06b6d4;
}

.install-copy {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 14px;
  border-radius: 6px;
  font-size: 0.85rem;
  font-weight: 600;
  color: #e2e8f0;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.15);
  transition: all var(--transition);
  white-space: nowrap;
}

.install-copy:hover {
  background: rgba(255, 255, 255, 0.15);
  border-color: rgba(255, 255, 255, 0.3);
}

.install-footnote {
  font-size: 0.875rem;
  line-height: 1.6;
  color: var(--color-text-light);
  margin: 0;
}

.install-footnote a {
  color: var(--color-primary);
  font-weight: 600;
}

.install-footnote a:hover {
  color: var(--color-primary-dark);
  text-decoration: underline;
}

/* Secondary cards (Windows / macOS) */
.install-grid {
  max-width: 880px;
  margin: 0 auto;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.install-card {
  display: flex;
  align-items: center;
  gap: 16px;
  background: var(--color-card-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  padding: 20px 24px;
  transition: all 0.25s ease;
  color: inherit;
}

.install-card:hover {
  border-color: var(--color-primary-light);
  box-shadow: var(--color-card-shadow-hover);
  transform: translateY(-2px);
}

.install-card-body {
  flex: 1;
  min-width: 0;
}

.install-card-title {
  font-size: 1.05rem;
  font-weight: 700;
  color: var(--color-text);
  margin-bottom: 2px;
}

.install-card-desc {
  font-size: 0.85rem;
  line-height: 1.5;
  color: var(--color-text-light);
}

.install-card-cta {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-primary);
  white-space: nowrap;
  flex-shrink: 0;
}

.install-card:hover .install-card-cta {
  color: var(--color-primary-dark);
}

/* Icons (shared) */
.install-icon {
  flex-shrink: 0;
  width: 48px;
  height: 48px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, rgba(37, 99, 235, 0.1), rgba(6, 182, 212, 0.1));
  color: var(--color-primary);
}

.install-primary .install-icon {
  width: 56px;
  height: 56px;
  border-radius: 12px;
}

.install-icon-mac {
  color: #1e293b;
  background: linear-gradient(135deg, rgba(30, 41, 59, 0.08), rgba(100, 116, 139, 0.08));
}

.install-icon-linux {
  color: #d97706;
  background: linear-gradient(135deg, rgba(217, 119, 6, 0.1), rgba(245, 158, 11, 0.1));
}

@media (max-width: 768px) {
  .install-primary {
    padding: 24px;
    gap: 20px;
  }

  .install-primary-head {
    gap: 14px;
  }

  .install-primary-title {
    font-size: 1.25rem;
  }

  .install-cmd {
    padding: 12px 14px;
  }

  .install-cmd-text {
    font-size: 0.85rem;
  }

  .install-copy span {
    display: none;
  }

  .install-grid {
    grid-template-columns: 1fr;
  }

  .install-card {
    padding: 16px 18px;
  }

  .install-card-cta {
    display: none;
  }
}
</style>
