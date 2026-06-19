import SwiftUI

/// Application settings sheet. Allows customizing VM storage and image cache directories.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var vmStorageDir: String
    @State private var imageCacheDir: String
    @State private var cacheSizeText: String = ""
    @State private var cacheImageCount: Int = 0

    private let settings = SettingsStore.shared
    private let fm = FileManager.default

    init() {
        let s = SettingsStore.shared
        _vmStorageDir = State(initialValue: s.vmStorageDirectory.path)
        _imageCacheDir = State(initialValue: s.imageCacheDirectory.path)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("设置")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - VM Storage Directory
                    GroupBox(label: Text("虚拟机存储位置")) {
                        vmStorageSection
                    }

                    // MARK: - Image Cache Directory
                    GroupBox(label: Text("镜像缓存位置")) {
                        imageCacheSection
                    }

                    // MARK: - Cache Info
                    GroupBox(label: Text("缓存")) {
                        cacheInfoSection
                    }
                }
                .padding()
            }

            HStack {
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 420, idealHeight: 460)
        .onAppear {
            refreshCacheInfo()
        }
    }

    // MARK: - VM Storage

    private var vmStorageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vmStorageDir)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                Button("浏览...") { browseVmStorageDir() }
                Button("重置") { resetVmStorageDir() }
                    .disabled(settings.vmStorageDirOverride == nil)
                Spacer()
            }
            Text("新建虚拟机将存储在此目录下。修改后，已有虚拟机仍保留在原位置。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Image Cache

    private var imageCacheSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(imageCacheDir)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                Button("浏览...") { browseImageCacheDir() }
                Button("重置") { resetImageCacheDir() }
                    .disabled(settings.imageCacheDirOverride == nil)
                Spacer()
            }
            Text("下载的镜像文件将存储在此目录下。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Cache Info

    private var cacheInfoSection: some View {
        HStack {
            Text(cacheSizeText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if cacheImageCount > 0 {
                Button("清除缓存") { clearCache() }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func browseVmStorageDir() {
        let panel = NSOpenPanel()
        panel.title = "选择虚拟机存储目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: vmStorageDir)
        if panel.runModal() == .OK, let url = panel.url {
            let oldDir = vmStorageDir
            let newPath = url.path
            settings.vmStorageDirOverride = newPath
            vmStorageDir = newPath
            migrateVmsIfNeeded(from: oldDir, to: newPath)
            appState.refreshVmList()
        }
    }

    private func resetVmStorageDir() {
        let oldDir = vmStorageDir
        settings.vmStorageDirOverride = nil
        vmStorageDir = settings.vmStorageDirectory.path
        migrateVmsIfNeeded(from: oldDir, to: vmStorageDir)
        appState.refreshVmList()
    }

    private func browseImageCacheDir() {
        let panel = NSOpenPanel()
        panel.title = "选择镜像缓存目录"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: imageCacheDir)
        if panel.runModal() == .OK, let url = panel.url {
            let oldDir = imageCacheDir
            let newPath = url.path
            settings.imageCacheDirOverride = newPath
            imageCacheDir = newPath
            migrateCacheIfNeeded(from: oldDir, to: newPath)
            refreshCacheInfo()
        }
    }

    private func resetImageCacheDir() {
        let oldDir = imageCacheDir
        settings.imageCacheDirOverride = nil
        imageCacheDir = settings.imageCacheDirectory.path
        migrateCacheIfNeeded(from: oldDir, to: imageCacheDir)
        refreshCacheInfo()
    }

    private func refreshCacheInfo() {
        let dir = settings.imageCacheDirectory.path
        guard fm.fileExists(atPath: dir) else {
            cacheSizeText = "无缓存"
            cacheImageCount = 0
            return
        }
        var totalBytes: UInt64 = 0
        var count = 0
        if let items = try? fm.contentsOfDirectory(atPath: dir) {
            for item in items {
                let itemPath = (dir as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue else { continue }
                let metaPath = (itemPath as NSString).appendingPathComponent("image.json")
                guard fm.fileExists(atPath: metaPath) else { continue }
                count += 1
                if let enumerator = fm.enumerator(atPath: itemPath) {
                    for case let file as String in enumerator {
                        let filePath = (itemPath as NSString).appendingPathComponent(file)
                        if let attrs = try? fm.attributesOfItem(atPath: filePath),
                           let size = attrs[.size] as? UInt64 {
                            totalBytes += size
                        }
                    }
                }
            }
        }
        cacheImageCount = count
        cacheSizeText = count == 0 ? "无缓存" : "\(count) 个镜像，\(formatBytes(totalBytes))"
    }

    private func migrateVmsIfNeeded(from oldDir: String, to newDir: String) {
        guard oldDir != newDir else { return }

        let oldUrl = URL(fileURLWithPath: oldDir)
        let newUrl = URL(fileURLWithPath: newDir)

        let configStore = VmConfigStore()
        let vmsToMigrate = configStore.vmsInDirectory(oldUrl)
        guard !vmsToMigrate.isEmpty else { return }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "迁移已有虚拟机？"
        alert.informativeText = "旧存储目录下存在 \(vmsToMigrate.count) 个虚拟机。是否迁移到新位置？\n\n旧路径：\(oldDir)\n新路径：\(newDir)"
        alert.addButton(withTitle: "迁移")
        alert.addButton(withTitle: "保留")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            var migrated = 0
            var failed = 0
            for vmId in vmsToMigrate {
                if configStore.migrateVm(id: vmId, from: oldUrl, to: newUrl) {
                    migrated += 1
                } else {
                    failed += 1
                }
            }
            let doneAlert = NSAlert()
            doneAlert.alertStyle = migrated > 0 ? .informational : .warning
            doneAlert.messageText = "迁移完成"
            var info = "已成功迁移 \(migrated)/\(vmsToMigrate.count) 个虚拟机。"
            if failed > 0 {
                info += "\n\(failed) 个虚拟机迁移失败，请检查日志。"
            }
            doneAlert.informativeText = info
            doneAlert.addButton(withTitle: "确定")
            doneAlert.runModal()
        }
    }

    private func clearCache() {
        let dir = settings.imageCacheDirectory.path
        guard fm.fileExists(atPath: dir) else { return }
        if let items = try? fm.contentsOfDirectory(atPath: dir) {
            for item in items {
                let itemPath = (dir as NSString).appendingPathComponent(item)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue {
                    try? fm.removeItem(atPath: itemPath)
                }
            }
        }
        refreshCacheInfo()
    }

    private func migrateCacheIfNeeded(from oldDir: String, to newDir: String) {
        guard oldDir != newDir, fm.fileExists(atPath: oldDir) else { return }
        guard let items = try? fm.contentsOfDirectory(atPath: oldDir) else { return }
        let imageItems = items.filter { item in
            let itemPath = (oldDir as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: itemPath, isDirectory: &isDir), isDir.boolValue else { return false }
            return fm.fileExists(atPath: (itemPath as NSString).appendingPathComponent("image.json"))
        }
        guard !imageItems.isEmpty else { return }

        // Prompt user to migrate or delete
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "迁移镜像缓存？"
        alert.informativeText = "旧缓存目录下存在 \(imageItems.count) 个已下载的镜像。是否迁移到新位置？\n\n旧路径：\(oldDir)"
        alert.addButton(withTitle: "迁移")
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "保留")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn: // Migrate
            for item in imageItems {
                let src = (oldDir as NSString).appendingPathComponent(item)
                let dest = (newDir as NSString).appendingPathComponent(item)
                try? fm.createDirectory(atPath: newDir, withIntermediateDirectories: true)
                if !fm.fileExists(atPath: dest) {
                    try? fm.moveItem(atPath: src, toPath: dest)
                }
            }
            // Clean up old directory if empty
            let remaining = (try? fm.contentsOfDirectory(atPath: oldDir)) ?? []
            if remaining.allSatisfy({ $0.hasPrefix(".") || !imageItems.contains($0) }) {
                // Only remove if all remaining items are dotfiles or non-image items
                for item in remaining {
                    try? fm.removeItem(atPath: (oldDir as NSString).appendingPathComponent(item))
                }
                try? fm.removeItem(atPath: oldDir)
            }
        case .alertSecondButtonReturn: // Delete
            for item in imageItems {
                let src = (oldDir as NSString).appendingPathComponent(item)
                try? fm.removeItem(atPath: src)
            }
        default: // Keep
            break
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_073_741_824 {
            String(format: "%.2f GB", Double(bytes) / 1_073_741_824.0)
        } else if bytes >= 1_048_576 {
            String(format: "%.1f MB", Double(bytes) / 1_048_576.0)
        } else if bytes >= 1024 {
            String(format: "%.0f KB", Double(bytes) / 1024.0)
        } else {
            "\(bytes) B"
        }
    }
}