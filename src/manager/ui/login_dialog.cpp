// Portions adapted from Starbox (GPL v3)
#include "manager/ui/login_dialog.h"
#include "manager/ui/dlg_builder.h"
#include "manager/i18n.h"

#define NOMINMAX
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>

#include <atomic>
#include <string>
#include <thread>

// ── Dialog control IDs ──

enum LoginDlgId {
    IDC_LOGIN_LOGO_LABEL  = 600,
    IDC_LOGIN_SUBTITLE    = 601,
    IDC_LOGIN_ERROR       = 602,
    IDC_LOGIN_STATUS      = 603,
    IDC_LOGIN_BTN         = IDOK,    // 1
    IDC_LOGIN_CANCEL_BTN  = IDCANCEL // 2
};

// WM_APP message sent from the background login thread back to the dialog:
//   WM_LOGIN_DONE  wParam=1 → success, lParam=unused
//   WM_LOGIN_DONE  wParam=0 → failure, lParam=unused  (error stored in data)
static constexpr UINT WM_LOGIN_DONE = WM_APP + 50;

struct LoginDlgData {
    const manager::OidcConfig *config;
    manager::OidcToken *out_token;
    HWND dlg;
    bool success;
    std::string error_msg;
    std::atomic<bool> thread_running{false};
    std::thread login_thread;
};

static void OpenBrowserUrl(const std::string &url) {
    std::wstring wurl(url.begin(), url.end());
    SHELLEXECUTEINFOW sei{sizeof(sei)};
    sei.lpVerb = L"open";
    sei.lpFile = wurl.c_str();
    sei.nShow  = SW_SHOWNORMAL;
    ShellExecuteExW(&sei);
}

static INT_PTR CALLBACK LoginDlgProc(HWND dlg, UINT msg, WPARAM wp, LPARAM lp) {
    auto *data = reinterpret_cast<LoginDlgData *>(
        GetWindowLongPtrW(dlg, DWLP_USER));

    switch (msg) {
    case WM_INITDIALOG: {
        data = reinterpret_cast<LoginDlgData *>(lp);
        data->dlg = dlg;
        SetWindowLongPtrW(dlg, DWLP_USER, reinterpret_cast<LONG_PTR>(data));
        CenterDialogToParent(dlg);

        // Hide error label initially
        ShowWindow(GetDlgItem(dlg, IDC_LOGIN_ERROR), SW_HIDE);
        ShowWindow(GetDlgItem(dlg, IDC_LOGIN_STATUS), SW_HIDE);

        // Disable login button if cloud_url is empty
        if (data->config->cloud_url.empty()) {
            EnableWindow(GetDlgItem(dlg, IDC_LOGIN_BTN), FALSE);
            SetDlgItemTextW(dlg, IDC_LOGIN_ERROR,
                i18n::to_wide(i18n::tr(i18n::S::kLoginCloudUrlEmpty)).c_str());
            ShowWindow(GetDlgItem(dlg, IDC_LOGIN_ERROR), SW_SHOW);
        }
        return TRUE;
    }

    case WM_COMMAND:
        switch (LOWORD(wp)) {
        case IDC_LOGIN_BTN: {
            if (data->thread_running.load()) return TRUE;

            // Clear previous error
            ShowWindow(GetDlgItem(dlg, IDC_LOGIN_ERROR), SW_HIDE);
            ShowWindow(GetDlgItem(dlg, IDC_LOGIN_STATUS), SW_SHOW);
            SetDlgItemTextW(dlg, IDC_LOGIN_STATUS,
                i18n::to_wide(i18n::tr(i18n::S::kLoginWaiting)).c_str());
            EnableWindow(GetDlgItem(dlg, IDC_LOGIN_BTN), FALSE);
            EnableWindow(GetDlgItem(dlg, IDC_LOGIN_CANCEL_BTN), FALSE);

            data->thread_running = true;

            // Launch OIDC flow in a background thread so the UI stays responsive.
            data->login_thread = std::thread([data]() {
                std::string err;
                manager::OidcToken token;
                bool ok = manager::OidcLogin(
                    *data->config,
                    [](const std::string &url) { OpenBrowserUrl(url); },
                    &token, &err);

                if (ok) {
                    // Attempt to enrich user info from /api/auth/me
                    std::string me_err;
                    manager::OidcFetchUserInfo(data->config->cloud_url,
                                              token.access_token, &token, &me_err);
                    *data->out_token = token;
                }

                data->success = ok;
                data->error_msg = err;
                data->thread_running = false;
                PostMessage(data->dlg, WM_LOGIN_DONE, ok ? 1 : 0, 0);
            });
            data->login_thread.detach();
            return TRUE;
        }
        case IDC_LOGIN_CANCEL_BTN:
            if (!data->thread_running.load()) {
                EndDialog(dlg, 0);
            }
            return TRUE;
        }
        break;

    case WM_LOGIN_DONE: {
        EnableWindow(GetDlgItem(dlg, IDC_LOGIN_BTN), TRUE);
        EnableWindow(GetDlgItem(dlg, IDC_LOGIN_CANCEL_BTN), TRUE);
        ShowWindow(GetDlgItem(dlg, IDC_LOGIN_STATUS), SW_HIDE);

        if (wp == 1) {
            // Success
            EndDialog(dlg, 1);
        } else {
            // Show error
            std::wstring err_w = i18n::to_wide(data->error_msg);
            SetDlgItemTextW(dlg, IDC_LOGIN_ERROR, err_w.c_str());
            ShowWindow(GetDlgItem(dlg, IDC_LOGIN_ERROR), SW_SHOW);
        }
        return TRUE;
    }

    case WM_CLOSE:
        if (!data || !data->thread_running.load()) {
            EndDialog(dlg, 0);
        }
        return TRUE;
    }
    return FALSE;
}

bool ShowLoginDialog(HWND parent, const manager::OidcConfig &config,
                     manager::OidcToken *out_token) {
    using S = i18n::S;

    DlgBuilder b;
    int W = 280, H = 170;
    b.Begin(i18n::tr(S::kLoginTitle), 0, 0, W, H,
            WS_POPUP | WS_CAPTION | WS_SYSMENU | DS_SETFONT);

    int x = 12, y = 14;

    // App name / logo label
    b.AddStatic(IDC_LOGIN_LOGO_LABEL, "Agent Sphere", x, y, W - 24, 14);
    y += 18;

    // Subtitle
    b.AddStatic(IDC_LOGIN_SUBTITLE,
                i18n::tr(S::kLoginSubtitle), x, y, W - 24, 20);
    y += 26;

    // Error label (hidden by default; multi-line)
    b.AddStatic(IDC_LOGIN_ERROR, "", x, y, W - 24, 26);
    // Status label (hidden by default)
    b.AddStatic(IDC_LOGIN_STATUS, "", x, y, W - 24, 12);
    y += 30;

    // Buttons row
    int btn_w = 68, btn_h = 14;
    int btn_y = H - 26;
    b.AddDefButton(IDC_LOGIN_BTN, i18n::tr(S::kLoginBtn),
                   W / 2 - btn_w - 4, btn_y, btn_w, btn_h);
    b.AddButton(IDC_LOGIN_CANCEL_BTN, i18n::tr(S::kDlgBtnCancel),
                W / 2 + 4, btn_y, btn_w, btn_h);

    LoginDlgData data{};
    data.config = &config;
    data.out_token = out_token;
    data.success = false;

    INT_PTR ret = DialogBoxIndirectParamW(
        GetModuleHandle(nullptr), b.Build(), parent,
        LoginDlgProc, reinterpret_cast<LPARAM>(&data));

    return ret == 1 && data.success;
}