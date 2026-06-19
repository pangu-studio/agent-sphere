import SwiftUI

struct InfoView: View {
    let vm: VmInfo

    private var vmDirectory: String {
        (vm.diskPath as NSString).deletingLastPathComponent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("常规") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "名称", value: vm.name)
                        InfoRow(label: "状态", value: vm.state.displayName)
                        InfoRow(label: "CPU", value: "\(vm.cpuCount)")
                        InfoRow(label: "内存", value: "\(vm.memoryMb) MB")
                        HStack(spacing: 16) {
                            Text("目录")
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                            HStack(spacing: 6) {
                                Text(vmDirectory)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 360, alignment: .leading)
                                    .help(vmDirectory)
                                Button {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: vmDirectory)
                                } label: {
                                    Image(systemName: "folder")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("在 Finder 中打开")
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .padding()
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
        }
    }
}

struct AddSharedFolderSheet: View {
    let vmId: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var tag = ""
    @State private var hostPath = ""
    @State private var readonly = false
    @State private var bookmarkData: Data?

    var body: some View {
        VStack(spacing: 0) {
            Text("添加共享文件夹")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()

            Form {
                TextField("标签", text: $tag)
                    .disableAutocorrection(true)
                HStack {
                    TextField("宿主机路径", text: $hostPath)
                    Button("浏览...") { browseFolder() }
                }
                Toggle("只读", isOn: $readonly)
            }
            .padding(.horizontal)

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加") { addFolder() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(tag.isEmpty || hostPath.isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 280)
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择共享文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            hostPath = url.path
            if tag.isEmpty {
                tag = url.lastPathComponent
            }
            bookmarkData = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    private func addFolder() {
        let folder = SharedFolder(tag: tag, hostPath: hostPath, readonly: readonly, bookmark: bookmarkData)
        appState.addSharedFolder(folder, toVm: vmId)
        dismiss()
    }
}

struct AddHostForwardSheet: View {
    let vmId: String
    var existing: HostForward? = nil
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: HostForwardField?

    @State private var nameText = ""
    @State private var hostIpText = "127.0.0.1"
    @State private var hostPortText = ""
    @State private var guestIpText = "10.0.2.15"
    @State private var guestPortText = ""

    private enum HostForwardField { case name, hostIp, hostPort, guestIp, guestPort }

    private var hostPort: UInt16? { UInt16(hostPortText) }
    private var guestPort: UInt16? { UInt16(guestPortText) }
    private var isValid: Bool {
        guard let hp = hostPort, let gp = guestPort else { return false }
        return hp >= 1 && gp >= 1 && !hostIpText.isEmpty
    }
    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "编辑宿主机 → 虚拟机" : "宿主机 → 虚拟机")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()

            Form {
                TextField("名称（可选）", text: $nameText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .name)
                TextField("宿主机 IP", text: $hostIpText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .hostIp)
                TextField("宿主机端口", text: $hostPortText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .hostPort)
                TextField("虚拟机 IP", text: .constant(guestIpText))
                    .disableAutocorrection(true)
                    .disabled(true)
                    .foregroundStyle(.secondary)
                TextField("虚拟机端口", text: $guestPortText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .guestPort)
            }
            .padding(.horizontal)
            .onAppear {
                if let pf = existing {
                    nameText = pf.name
                    hostIpText = pf.effectiveHostIp
                    hostPortText = String(pf.hostPort)
                    guestPortText = String(pf.guestPort)
                }
                focusedField = .name
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "保存" : "添加") { addHostForward() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 340, height: 300)
    }

    private func addHostForward() {
        guard let hp = hostPort, let gp = guestPort else { return }
        if let old = existing {
            appState.removeHostForward(hostPort: old.hostPort, fromVm: vmId)
        }
        let pf = HostForward(name: nameText, hostPort: hp, guestPort: gp, hostIp: hostIpText, guestIp: guestIpText)
        appState.addHostForward(pf, toVm: vmId)
        dismiss()
    }
}

struct AddGuestForwardSheet: View {
    let vmId: String
    var existing: GuestForward? = nil
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: GuestForwardField?

    @State private var nameText = ""
    @State private var guestIpText = "10.0.2.2"
    @State private var guestPortText = ""
    @State private var hostAddrText = "127.0.0.1"
    @State private var hostPortText = ""

    private enum GuestForwardField { case name, guestIp, guestPort, hostAddr, hostPort }

    private var guestPort: UInt16? { UInt16(guestPortText) }
    private var hostPort: UInt16? { UInt16(hostPortText) }
    private var isValid: Bool {
        guard let gp = guestPort, let hp = hostPort else { return false }
        return gp >= 1 && hp >= 1 && !guestIpText.isEmpty && !hostAddrText.isEmpty
    }
    private var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "编辑虚拟机 → 宿主机" : "虚拟机 → 宿主机")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()

            Form {
                TextField("名称（可选）", text: $nameText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .name)
                TextField("虚拟机 IP", text: $guestIpText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .guestIp)
                TextField("虚拟机端口", text: $guestPortText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .guestPort)
                TextField("宿主机地址", text: $hostAddrText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .hostAddr)
                TextField("宿主机端口", text: $hostPortText)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .hostPort)
            }
            .padding(.horizontal)
            .onAppear {
                if let gf = existing {
                    nameText = gf.name
                    guestIpText = gf.guestIp
                    guestPortText = String(gf.guestPort)
                    hostAddrText = gf.effectiveHostAddr
                    hostPortText = String(gf.hostPort)
                }
                focusedField = .name
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "保存" : "添加") { addGuestForward() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 340, height: 300)
    }

    private func addGuestForward() {
        guard let gp = guestPort, let hp = hostPort else { return }
        if let old = existing {
            appState.removeGuestForward(guestIp: old.guestIp, guestPort: old.guestPort, fromVm: vmId)
        }
        let gf = GuestForward(name: nameText, guestIp: guestIpText, guestPort: gp, hostAddr: hostAddrText, hostPort: hp)
        appState.addGuestForward(gf, toVm: vmId)
        dismiss()
    }
}

struct SharedFoldersSheet: View {
    let vmId: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSheet = false

    private var vm: VmInfo? {
        appState.vms.first(where: { $0.id == vmId })
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("共享文件夹")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()

            if let vm = vm {
                if vm.sharedFolders.isEmpty {
                    Text("暂无共享文件夹")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.sharedFolders) { folder in
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.tag)
                                        .fontWeight(.medium)
                                    Text(folder.hostPath)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                if folder.readonly {
                                    Text("只读")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                Button(role: .destructive) {
                                    appState.removeSharedFolder(tag: folder.tag, fromVm: vmId)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }

            Text("共享文件夹将作为桌面快捷方式出现在虚拟机中，方便在宿主机与虚拟机之间交换文件。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)

            HStack {
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 480, height: 400)
        .sheet(isPresented: $showAddSheet) {
            AddSharedFolderSheet(vmId: vmId)
        }
    }
}

struct PortForwardsSheet: View {
    let vmId: String
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPfSheet = false
    @State private var showAddGfSheet = false
    @State private var editingPf: HostForward? = nil
    @State private var editingGf: GuestForward? = nil

    private var vm: VmInfo? {
        appState.vms.first(where: { $0.id == vmId })
    }

    var body: some View {
        VStack(spacing: 0) {
            if let vm = vm {
                // 宿主机 -> 虚拟机 section
                HStack {
                    Text("宿主机 \u{2192} 虚拟机")
                        .font(.headline)
                    Spacer()
                    Button {
                        showAddPfSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
                .padding(.top)

                if vm.hostForwards.isEmpty {
                    Text("暂无端口转发")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.hostForwards) { pf in
                            HStack(spacing: 8) {
                                Image(systemName: "network")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    if !pf.name.isEmpty {
                                        Text(pf.name)
                                            .fontWeight(.medium)
                                    }
                                    let guestDisplay = pf.guestIp.isEmpty ? "10.0.2.15" : pf.guestIp
                                    Text(verbatim: "\(pf.effectiveHostIp):\(pf.hostPort) \u{2192} \(guestDisplay):\(pf.guestPort)")
                                        .foregroundStyle(pf.name.isEmpty ? .primary : .secondary)
                                        .font(pf.name.isEmpty ? .body : .caption)
                                }
                                Spacer()
                                Button {
                                    editingPf = pf
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("编辑")
                                Button(role: .destructive) {
                                    appState.removeHostForward(hostPort: pf.hostPort, fromVm: vmId)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                Divider()

                // 虚拟机 -> 宿主机 section
                HStack {
                    Text("虚拟机 \u{2192} 宿主机")
                        .font(.headline)
                    Spacer()
                    Button {
                        showAddGfSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if vm.guestForwards.isEmpty {
                    Text("暂无反向转发")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(vm.guestForwards) { gf in
                            HStack(spacing: 8) {
                                Image(systemName: "network")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    if !gf.name.isEmpty {
                                        Text(gf.name)
                                            .fontWeight(.medium)
                                    }
                                    Text(verbatim: "\(gf.guestIp):\(gf.guestPort) \u{2192} \(gf.effectiveHostAddr):\(gf.hostPort)")
                                        .foregroundStyle(gf.name.isEmpty ? .primary : .secondary)
                                        .font(gf.name.isEmpty ? .body : .caption)
                                }
                                Spacer()
                                Button {
                                    editingGf = gf
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .help("编辑")
                                Button(role: .destructive) {
                                    appState.removeGuestForward(guestIp: gf.guestIp, guestPort: gf.guestPort, fromVm: vmId)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }

            HStack {
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()
        }
        .frame(width: 460, height: 480)
        .sheet(isPresented: $showAddPfSheet) {
            AddHostForwardSheet(vmId: vmId)
        }
        .sheet(item: $editingPf) { pf in
            AddHostForwardSheet(vmId: vmId, existing: pf)
        }
        .sheet(isPresented: $showAddGfSheet) {
            AddGuestForwardSheet(vmId: vmId)
        }
        .sheet(item: $editingGf) { gf in
            AddGuestForwardSheet(vmId: vmId, existing: gf)
        }
    }
}
