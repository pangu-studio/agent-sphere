import SwiftUI

struct VmListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var oidcService: OidcService

    private var sortedVms: [VmInfo] {
        appState.vms.sorted { a, b in
            let aPriority = a.state.sortPriority
            let bPriority = b.state.sortPriority
            if aPriority != bPriority {
                return aPriority < bPriority
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.selectedVmId) {
                ForEach(sortedVms) { vm in
                    VmRowView(vm: vm)
                        .tag(vm.id)
                }
            }
            .listStyle(.sidebar)

            Divider()

            UserInfoFooter(oidcService: oidcService)
        }
        .navigationTitle("AgentSphere")
    }
}

// MARK: - 底部用户信息栏

private struct UserInfoFooter: View {
    @ObservedObject var oidcService: OidcService
    @EnvironmentObject var appState: AppState
    @State private var showLogoutConfirm = false

    var body: some View {
        if oidcService.isAuthenticated {
            authenticatedFooter
        } else {
            loginFooter
        }
    }

    // MARK: - 已登录状态

    private var authenticatedFooter: some View {
        HStack(spacing: 10) {
            // 头像占位（首字母）
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text(avatarLetter)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(oidcService.userInfo?.displayName ?? "已登录")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if let email = oidcService.userInfo?.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showLogoutConfirm = true
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("退出登录")
            .confirmationDialog("确认退出登录？", isPresented: $showLogoutConfirm) {
                Button("退出登录", role: .destructive) {
                    oidcService.logout()
                }
                Button("取消", role: .cancel) {}
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - 未登录状态

    private var loginFooter: some View {
        VStack(spacing: 8) {
            if let error = oidcService.loginError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }

            if oidcService.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for browser…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    oidcService.login(
                        cloudUrl: appState.cloudUrl,
                        oidcIssuer: appState.oidcIssuer
                    )
                } label: {
                    Label("登录", systemImage: "person.badge.key.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(appState.cloudUrl.isEmpty || appState.oidcIssuer.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var avatarLetter: String {
        let name = oidcService.userInfo?.displayName ?? ""
        return String(name.first ?? "?").uppercased()
    }
}

struct VmRowView: View {
    let vm: VmInfo

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(vm.state.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var stateColor: Color {
        switch vm.state {
        case .running: return .green
        case .starting, .rebooting: return .orange
        case .stopped: return .gray
        case .crashed: return .red
        }
    }
}
