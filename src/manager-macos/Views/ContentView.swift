import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var oidcService: OidcService

    private var selectedVm: VmInfo? {
        guard let vmId = appState.selectedVmId else { return nil }
        return appState.vms.first(where: { $0.id == vmId })
    }

    var body: some View {
        mainView
    }

    private var mainView: some View {
        Group {
            if appState.isVmDisplayFullscreen {
                fullscreenView
            } else {
                normalView
            }
        }
    }

    // 全屏模式：仅显示 VM 画面，隐藏侧边栏和工具栏
    @ViewBuilder
    private var fullscreenView: some View {
        if let vm = selectedVm {
            VmDetailView(vm: vm, appState: appState)
                .id(vm.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
    }

    // 普通模式：NavigationView + 侧边栏 + 工具栏
    private var normalView: some View {
        NavigationView {
            VmListView()
            detailView
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { appState.showCreateVmDialog = true }) {
                    Label("新建 Agent Box", systemImage: "plus.rectangle")
                }
                .help("创建一个新的 Agent Box")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if let vm = selectedVm {
                    Button(action: { appState.showEditVmDialog = true }) {
                        Label("编辑", systemImage: "pencil")
                    }
                    .disabled(vm.state == .running)
                    .help("编辑 Agent Box 设置")

                    Button(action: { appState.cloneVm(id: vm.id) }) {
                        Label("克隆", systemImage: "doc.on.doc")
                    }
                    .disabled(vm.state == .running)
                    .help("克隆此 Agent Box")

                    Button(
                        role: .destructive,
                        action: {
                            appState.showDeleteConfirm = true
                        }
                    ) {
                        Label("删除", systemImage: "trash")
                    }
                    .disabled(vm.state == .running)
                    .help("删除此 Agent Box")

                    Divider()
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                if let vm = selectedVm {
                    if vm.state == .stopped || vm.state == .crashed {
                        Button(action: { appState.requestStartVm(id: vm.id) }) {
                            Label("启动", systemImage: "play.fill")
                        }
                        .help("启动 Agent Box")
                    }

                    if vm.state == .running {
                        Button(action: { appState.showForceStopConfirm = true }) {
                            Label("强制停止", systemImage: "stop.fill")
                        }
                        .help("立即强制停止 Agent Box（可能导致数据丢失）")

                        Button(action: { appState.rebootVm(id: vm.id) }) {
                            Label("重启", systemImage: "arrow.clockwise")
                        }
                        .help("重启 Agent Box")

                        Button(action: { appState.shutdownVm(id: vm.id) }) {
                            Label("关闭", systemImage: "power")
                        }
                        .help("优雅地关闭 Agent Box")

                        Divider()

                        Button(action: {
                            appState.setDisplayScale(vm.displayScale == 1 ? 2 : 1, forVm: vm.id)
                        }) {
                            Label(
                                vm.displayScale == 2 ? "显示 1x" : "显示 2x",
                                systemImage: vm.displayScale == 2
                                    ? "minus.magnifyingglass" : "plus.magnifyingglass")
                        }
                        .help(
                            vm.displayScale == 2
                                ? "切换到 1x 显示比例" : "切换到 2x Retina 显示比例"
                        )
                    }

                    Divider()

                    Button(action: { appState.showSharedFoldersSheet = true }) {
                        ToolbarBadgeLabel(
                            title: "共享文件夹",
                            systemImage: "folder",
                            count: vm.sharedFolders.count
                        )
                    }
                    .help("管理共享文件夹")

                    Button(action: { appState.showPortForwardsSheet = true }) {
                        ToolbarBadgeLabel(
                            title: "端口转发",
                            systemImage: "network.badge.shield.half.filled",
                            count: vm.hostForwards.count + vm.guestForwards.count
                        )
                    }
                    .help("管理端口转发设置")

                    Button(action: { appState.showLlmProxySheet = true }) {
                        ToolbarBadgeLabel(
                            title: "LLM 代理",
                            systemImage: "key.viewfinder",
                            count: appState.llmMappings.count
                        )
                    }
                    .help("管理 LLM 代理设置")

                    Picker("", selection: appState.activeTabBinding(for: vm.id)) {
                        Image(systemName: "info.circle").tag(0)
                        Image(systemName: "terminal").tag(1)
                        Image(systemName: "display").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 180)
                }
            }
        }
        .sheet(isPresented: $appState.showCreateVmDialog) {
            CreateVmDialog()
        }
        .sheet(isPresented: $appState.showEditVmDialog) {
            if let vm = selectedVm {
                EditVmDialog(vm: vm)
            }
        }
        .sheet(isPresented: $appState.showSharedFoldersSheet) {
            if let vm = selectedVm {
                SharedFoldersSheet(vmId: vm.id)
            }
        }
        .sheet(isPresented: $appState.showPortForwardsSheet) {
            if let vm = selectedVm {
                PortForwardsSheet(vmId: vm.id)
            }
        }
        .sheet(isPresented: $appState.showLlmProxySheet) {
            LlmProxySheet()
        }
        .sheet(isPresented: $appState.showSettings) {
            SettingsView()
        }
        .alert("删除 Agent Box", isPresented: $appState.showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let vm = selectedVm {
                    appState.deleteVm(id: vm.id)
                }
            }
        } message: {
            Text(
                "您确定要删除 \"\(selectedVm?.name ?? "")\" 吗？此操作无法撤销。"
            )
        }
        .alert("Force Stop VM", isPresented: $appState.showForceStopConfirm) {
            Button("取消", role: .cancel) {}
            Button("强制停止", role: .destructive) {
                if let vm = selectedVm {
                    appState.stopVm(id: vm.id)
                }
            }
        } message: {
            Text(
                "您确定要强制停止 \"\(selectedVm?.name ?? "")\" 吗？未保存的数据可能会丢失。"
            )
        }
        .alert(
            "启用完全键盘捕获？",
            isPresented: $appState.showKeyboardCapturePermissionAlert
        ) {
            Button("请求权限") {
                appState.requestKeyboardCapturePermissions()
            }
            .keyboardShortcut(.defaultAction)
            Button("继续使用") {
                appState.startPendingVmWithoutPermissionPrompt()
            }
            Button("取消", role: .cancel) {
                appState.dismissKeyboardCapturePermissionPrompt()
            }
        } message: {
            keyboardCapturePermissionMessage
        }
        .alert("启动 Agent Box 失败", isPresented: showStartVmErrorBinding) {
            Button("确定", role: .cancel) {
                appState.startVmError = nil
            }
        } message: {
            Text(appState.startVmError ?? "")
        }
        .onChange(of: appState.hostForwardError) { error in
            guard let msg = error else { return }
            appState.hostForwardError = nil
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "端口转发错误"
            alert.informativeText = msg
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    private var showStartVmErrorBinding: Binding<Bool> {
        Binding(
            get: { appState.startVmError != nil },
            set: { if !$0 { appState.startVmError = nil } }
        )
    }

    @ViewBuilder
    private var detailView: some View {
        if let vm = selectedVm {
            VmDetailView(vm: vm, appState: appState)
                .id(vm.id)
                .navigationTitle(vm.name)
        } else {
            Text("选择 Agent Box")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("")
        }
    }

    private var keyboardCapturePermissionMessage: Text {
        return Text("完全键盘捕获需要 ") + Text("辅助功能").bold()
            + Text(
                " 权限。\n\n您可以继续使用而不进行完全捕获，或立即请求权限。"
            )
    }
}

private struct ToolbarBadgeLabel: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        Label {
            Text(title)
        } icon: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemImage)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 12, minHeight: 12)
                        .background(.secondary, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}
