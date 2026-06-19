import Foundation

class VmConfigStore {

    private var settings: SettingsStore { SettingsStore.shared }

    /// The effective VM storage directory (may be overridden via settings.json).
    private var vmsDirectory: URL { settings.vmStorageDirectory }

    /// The default VM storage directory (always ~/Library/Application Support/AgentSphere/vms/).
    /// Used to discover VMs at the legacy path when a custom vm_storage_dir is active.
    private var defaultVmsDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("AgentSphere/vms")
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Paths

    func vmDirectory(for vmId: String) -> URL {
        vmsDirectory.appendingPathComponent(vmId)
    }

    /// Returns the actual VM directory on disk, checking the effective path first,
    /// then falling back to the default path.
    func actualVmDirectory(for vmId: String) -> URL {
        let url = vmDirectory(for: vmId)
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return defaultVmsDirectory.appendingPathComponent(vmId)
    }

    func configURL(for vmId: String) -> URL {
        vmDirectory(for: vmId).appendingPathComponent("config.json")
    }

    // MARK: - Read / Write

    func readConfig(vmId: String, fromDir parentDir: URL? = nil) -> VmConfig? {
        // Use the hinted directory if provided, otherwise try effective then default.
        let configUrl: URL
        if let parent = parentDir {
            configUrl = parent.appendingPathComponent(vmId).appendingPathComponent("config.json")
        } else {
            configUrl = configURL(for: vmId)
        }

        let data: Data?
        if FileManager.default.fileExists(atPath: configUrl.path) {
            data = try? Data(contentsOf: configUrl)
        } else if parentDir == nil {
            // Only fall back to default if no explicit directory was given
            let fallbackUrl = defaultVmsDirectory.appendingPathComponent(vmId).appendingPathComponent("config.json")
            data = try? Data(contentsOf: fallbackUrl)
        } else {
            data = nil
        }
        guard let data = data else { return nil }
        guard var config = try? decoder.decode(VmConfig.self, from: data) else { return nil }

        // Resolve relative paths against the actual VM directory on disk.
        let actualVmDir = configUrl.deletingLastPathComponent().path
        func resolve(_ path: String) -> String {
            guard !path.isEmpty, !path.hasPrefix("/") else { return path }
            return (actualVmDir as NSString).appendingPathComponent(path)
        }
        config.kernelPath = resolve(config.kernelPath)
        config.initrdPath = resolve(config.initrdPath)
        config.diskPath = resolve(config.diskPath)
        return config
    }

    @discardableResult
    func writeConfig(vmId: String, config: VmConfig) -> Bool {
        guard let data = try? encoder.encode(config) else { return false }
        let url = configURL(for: vmId)
        // Write to the effective directory if the config already exists there,
        // otherwise use the default directory.
        let writeUrl: URL
        if FileManager.default.fileExists(atPath: url.path) {
            writeUrl = url
        } else {
            let fallbackUrl = defaultVmsDirectory.appendingPathComponent(vmId).appendingPathComponent("config.json")
            writeUrl = FileManager.default.fileExists(atPath: fallbackUrl.path) ? fallbackUrl : url
        }
        return FileManager.default.createFile(atPath: writeUrl.path, contents: data)
    }

    // MARK: - List

    func listVms() -> [(id: String, config: VmConfig)] {
        let fm = FileManager.default
        var seenIds = Set<String>()
        var result: [(id: String, config: VmConfig)] = []

        // Scan both the effective VMs directory and the default directory,
        // so VMs at the legacy path remain visible when a custom path is active.
        for dir in [vmsDirectory, defaultVmsDirectory] {
            guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for item in items {
                guard !seenIds.contains(item) else { continue }
                seenIds.insert(item)
                guard let config = readConfig(vmId: item, fromDir: dir) else { continue }
                result.append((id: item, config: config))
            }
        }
        return result
    }

    // MARK: - Create

    @discardableResult
    func createVm(from createConfig: VmCreateConfig) -> String? {
        let vmId = UUID().uuidString
        let vmDir = vmDirectory(for: vmId)
        let fm = FileManager.default

        guard (try? fm.createDirectory(at: vmDir, withIntermediateDirectories: true)) != nil else {
            return nil
        }

        func copyFile(_ srcPath: String) -> String {
            guard !srcPath.isEmpty else { return "" }
            let fileName = (srcPath as NSString).lastPathComponent
            let dest = vmDir.appendingPathComponent(fileName).path
            do {
                try fm.copyItem(atPath: srcPath, toPath: dest)
                return fileName
            } catch {
                NSLog("Failed to copy %@ -> %@: %@", srcPath, dest, error.localizedDescription)
                return srcPath
            }
        }

        let kernelPath = createConfig.kernelPath.isEmpty ? "" : copyFile(createConfig.kernelPath)
        let initrdPath = createConfig.initrdPath.isEmpty ? "" : copyFile(createConfig.initrdPath)
        let diskPath = createConfig.diskPath.isEmpty ? "" : copyFile(createConfig.diskPath)

        let config = VmConfig(
            name: createConfig.name,
            kernelPath: kernelPath,
            initrdPath: initrdPath,
            diskPath: diskPath,
            memoryMb: createConfig.memoryMb,
            cpuCount: createConfig.cpuCount,
            state: "stopped",
            netEnabled: createConfig.netEnabled,
            debugMode: createConfig.debugMode,
            displayScale: 1
        )

        guard writeConfig(vmId: vmId, config: config) else { return nil }
        return vmId
    }

    // MARK: - Edit

    @discardableResult
    func editVm(
        id: String, name: String, memoryMb: Int, cpuCount: Int,
        netEnabled: Bool, debugMode: Bool,
        kernelPath: String? = nil, initrdPath: String? = nil, diskPath: String? = nil
    ) -> Bool {
        guard var config = readConfig(vmId: id) else { return false }
        config.name = name
        config.memoryMb = memoryMb
        config.cpuCount = cpuCount
        config.netEnabled = netEnabled
        config.debugMode = debugMode
        if let kp = kernelPath { config.kernelPath = kp }
        if let ip = initrdPath { config.initrdPath = ip }
        if let dp = diskPath { config.diskPath = dp }
        return writeConfig(vmId: id, config: config)
    }

    // MARK: - Clone

    /// Clones a stopped VM: copies the entire directory, generates a unique name, and clears port forwards.
    /// Returns the new VM id on success, nil on failure.
    @discardableResult
    func cloneVm(id: String) -> String? {
        guard let srcConfig = readConfig(vmId: id) else { return nil }

        let newId = UUID().uuidString
        // Find the actual source directory (may be in default or effective path).
        let effectiveSrcDir = vmDirectory(for: id)
        let srcDir: URL
        if FileManager.default.fileExists(atPath: effectiveSrcDir.path) {
            srcDir = effectiveSrcDir
        } else {
            srcDir = defaultVmsDirectory.appendingPathComponent(id)
        }
        let destDir = vmDirectory(for: newId)

        do {
            try FileManager.default.copyItem(at: srcDir, to: destDir)
        } catch {
            NSLog("Failed to clone VM directory: %@", error.localizedDescription)
            return nil
        }

        guard var newConfig = readConfig(vmId: newId) else {
            try? FileManager.default.removeItem(at: destDir)
            return nil
        }

        newConfig.name = generateCloneName(baseName: srcConfig.name)
        newConfig.state = "stopped"
        newConfig.hostForwards = []

        let srcPrefix = srcDir.path + "/"
        let destPrefix = destDir.path + "/"
        func toRelative(_ path: String) -> String {
            guard !path.isEmpty else { return path }
            if path.hasPrefix(srcPrefix) {
                return String(path.dropFirst(srcPrefix.count))
            }
            if path.hasPrefix(destPrefix) {
                return String(path.dropFirst(destPrefix.count))
            }
            if !path.hasPrefix("/") {
                return path
            }
            return path
        }
        newConfig.kernelPath = toRelative(newConfig.kernelPath)
        newConfig.initrdPath = toRelative(newConfig.initrdPath)
        newConfig.diskPath = toRelative(newConfig.diskPath)

        guard writeConfig(vmId: newId, config: newConfig) else {
            try? FileManager.default.removeItem(at: destDir)
            return nil
        }
        return newId
    }

    private func generateCloneName(baseName: String) -> String {
        var stem = baseName
        var startNum = 2

        if let range = stem.range(of: #"\s+\d+$"#, options: .regularExpression) {
            let numStr = stem[range].trimmingCharacters(in: .whitespaces)
            if let existing = Int(numStr), existing > 0 {
                stem = String(stem[..<range.lowerBound])
                startNum = existing + 1
            }
        }

        let existingNames = Set(listVms().map(\.config.name))
        for n in startNum... {
            let candidate = "\(stem) \(n)"
            if !existingNames.contains(candidate) { return candidate }
        }
        return "\(stem) \(startNum)"
    }

    // MARK: - Delete

    @discardableResult
    func deleteVm(id: String) -> Bool {
        let url = vmDirectory(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            return (try? FileManager.default.removeItem(at: url)) != nil
        }
        let fallbackUrl = defaultVmsDirectory.appendingPathComponent(id)
        return (try? FileManager.default.removeItem(at: fallbackUrl)) != nil
    }

    // MARK: - Migrate

    /// Returns VM IDs that exist in the given directory.
    func vmsInDirectory(_ dir: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        return items.filter { item in
            let configPath = dir.appendingPathComponent(item).appendingPathComponent("config.json").path
            return fm.fileExists(atPath: configPath)
        }
    }

    /// Moves a VM directory from srcDir to dstDir. Returns true on success.
    /// Uses copy + delete fallback for cross-volume moves.
    /// After moving, rewrites config.json to ensure all paths are relative to the new location.
    @discardableResult
    func migrateVm(id: String, from srcDir: URL, to dstDir: URL) -> Bool {
        let src = srcDir.appendingPathComponent(id)
        let dst = dstDir.appendingPathComponent(id)
        let fm = FileManager.default
        guard fm.fileExists(atPath: src.path) else { return false }
        guard !fm.fileExists(atPath: dst.path) else { return false }
        do {
            try fm.createDirectory(at: dstDir, withIntermediateDirectories: true)
            try fm.moveItem(at: src, to: dst)
        } catch {
            // Cross-volume move not supported; fall back to copy + delete
            NSLog("Move failed (likely cross-volume), trying copy+delete: %@", error.localizedDescription)
            do {
                try fm.copyItem(at: src, to: dst)
                try fm.removeItem(at: src)
            } catch {
                NSLog("Failed to migrate VM %@: %@", id, error.localizedDescription)
                try? fm.removeItem(at: dst)
                return false
            }
        }

        // Rewrite config.json with paths relative to the new VM directory.
        rewriteConfigWithRelativePaths(vmId: id, vmDir: dst)
        return true
    }

    /// Reads config.json from the given vmDir and rewrites it with paths relative to that directory.
    /// This ensures that after migration, all paths resolve correctly.
    private func rewriteConfigWithRelativePaths(vmId: String, vmDir: URL) {
        let configPath = vmDir.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configPath),
              var config = try? decoder.decode(VmConfig.self, from: data) else { return }

        let dirPath = vmDir.path
        func makeRelative(_ path: String) -> String {
            guard !path.isEmpty else { return path }
            // If already under this directory, make it relative
            if path.hasPrefix(dirPath + "/") {
                return String(path.dropFirst(dirPath.count + 1))
            }
            // If it's already relative, keep it
            if !path.hasPrefix("/") {
                return path
            }
            // Absolute path elsewhere — keep as-is (file wasn't copied into VM dir)
            return path
        }

        config.kernelPath = makeRelative(config.kernelPath)
        config.initrdPath = makeRelative(config.initrdPath)
        config.diskPath = makeRelative(config.diskPath)

        guard let newData = try? encoder.encode(config) else { return }
        try? newData.write(to: configPath)
    }

    // MARK: - State

    @discardableResult
    func updateState(vmId: String, state: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        config.state = state
        return writeConfig(vmId: vmId, config: config)
    }

    // MARK: - Display Scale

    @discardableResult
    func setDisplayScale(vmId: String, scale: Int) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        config.displayScale = max(1, min(2, scale))
        return writeConfig(vmId: vmId, config: config)
    }

    // MARK: - Shared Folders

    @discardableResult
    func addSharedFolder(_ folder: SharedFolder, toVm vmId: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        if config.sharedFolders.contains(where: { $0.tag == folder.tag }) { return false }
        config.sharedFolders.append(SharedFolderConfig.from(folder))
        return writeConfig(vmId: vmId, config: config)
    }

    @discardableResult
    func removeSharedFolder(tag: String, fromVm vmId: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        guard let idx = config.sharedFolders.firstIndex(where: { $0.tag == tag }) else {
            return false
        }
        config.sharedFolders.remove(at: idx)
        return writeConfig(vmId: vmId, config: config)
    }

    @discardableResult
    func setSharedFolders(_ folders: [SharedFolder], forVm vmId: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        config.sharedFolders = folders.map { SharedFolderConfig.from($0) }
        return writeConfig(vmId: vmId, config: config)
    }

    // MARK: - Port Forwards

    @discardableResult
    func addHostForward(_ pf: HostForward, toVm vmId: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        if config.hostForwards.contains(where: { $0.hostPort == pf.hostPort }) { return false }
        config.hostForwards.append(HostForwardConfig.from(pf))
        return writeConfig(vmId: vmId, config: config)
    }

    @discardableResult
    func removeHostForward(hostPort: UInt16, fromVm vmId: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        guard let idx = config.hostForwards.firstIndex(where: { $0.hostPort == hostPort }) else {
            return false
        }
        config.hostForwards.remove(at: idx)
        return writeConfig(vmId: vmId, config: config)
    }

    // MARK: - Guest Forwards

    @discardableResult
    func addGuestForward(_ gf: GuestForward, toVm vmId: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        if config.guestForwards.contains(where: {
            $0.guestIp == gf.guestIp && $0.guestPort == gf.guestPort
        }) {
            return false
        }
        config.guestForwards.append(GuestForwardConfig.from(gf))
        return writeConfig(vmId: vmId, config: config)
    }

    @discardableResult
    func removeGuestForward(guestIp: String, guestPort: UInt16, fromVm vmId: String) -> Bool {
        guard var config = readConfig(vmId: vmId) else { return false }
        guard
            let idx = config.guestForwards.firstIndex(where: {
                $0.guestIp == guestIp && $0.guestPort == guestPort
            })
        else { return false }
        config.guestForwards.remove(at: idx)
        return writeConfig(vmId: vmId, config: config)
    }
}
