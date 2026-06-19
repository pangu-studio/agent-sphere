// Portions adapted from Starbox (GPL v3)
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var oidcService: OidcService
    let cloudUrl: String
    let oidcIssuer: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image = NSImage(named: "AppIcon") {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            Text("Agent Sphere")
                .font(.largeTitle.bold())

            Text("登录以继续使用 Agent Sphere 管理器")
                .font(.body)
                .foregroundStyle(.secondary)

            // 错误提示
            if let error = oidcService.loginError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .frame(maxWidth: 360)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            if oidcService.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for browser…")
                        .foregroundStyle(.secondary)
                }
                .frame(height: 32)
            } else {
                Button {
                    oidcService.login(cloudUrl: cloudUrl, oidcIssuer: oidcIssuer)
                } label: {
                    Label("登录", systemImage: "person.badge.key.fill")
                        .frame(width: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(cloudUrl.isEmpty || oidcIssuer.isEmpty)
            }

            if cloudUrl.isEmpty {
                Text("Cloud URL 未配置")
                    .font(.caption).foregroundStyle(.red)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}