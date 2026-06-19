import AppKit
import SwiftUI

struct LlmProxySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSheet = false
    @State private var editMapping: LlmModelMapping?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LLM 代理")
                    .font(.headline)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.top)

            if appState.llmMappings.isEmpty {
                Text("暂无模型映射")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(appState.llmMappings) { mapping in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mapping.alias)
                                    .fontWeight(.medium)
                                Text("\(mapping.targetUrl) · \(mapping.model)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                editMapping = mapping
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            Button(role: .destructive) {
                                appState.removeLlmMapping(alias: mapping.alias)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Text("虚拟机可通过 http://10.0.2.3/ 使用任意 API 密钥访问 LLM 接口。模型别名映射到已配置的 LLM 后端，API 凭证安全保存在宿主机上。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)

            Divider()

            HStack {
                Toggle("启用请求日志", isOn: Binding(
                    get: { appState.llmLoggingEnabled },
                    set: { appState.setLlmLogging(enabled: $0) }
                ))
                .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 6)

            HStack(spacing: 4) {
                Text("日志保存路径：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    let dir = LlmProxyService.logDir
                    try? FileManager.default.createDirectory(
                        atPath: dir, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                } label: {
                    Text(LlmProxyService.logDir.replacingOccurrences(
                        of: NSHomeDirectory(), with: "~"))
                        .font(.caption)
                }
                .buttonStyle(.link)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            HStack {
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()
        }
        .frame(width: 440, height: 440)
        .sheet(isPresented: $showAddSheet) {
            EditLlmMappingSheet(mode: .add)
        }
        .sheet(item: $editMapping) { mapping in
            EditLlmMappingSheet(mode: .edit(mapping))
        }
    }
}

struct EditLlmMappingSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(LlmModelMapping)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let m): return m.alias
            }
        }
    }

    let mode: Mode
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var alias = ""
    @State private var targetUrl = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var apiType: LlmApiType = .openaiCompletions

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var originalAlias: String? {
        if case .edit(let m) = mode { return m.alias }
        return nil
    }

    private var isValid: Bool {
        !alias.trimmingCharacters(in: .whitespaces).isEmpty &&
        !targetUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEdit ? "编辑映射" : "添加映射")
                .font(.title3)
                .fontWeight(.semibold)
                .padding()

            Form {
                TextField("别名", text: $alias, prompt: Text("例如 default"))
                    .disableAutocorrection(true)
                Picker("API 类型", selection: $apiType) {
                    ForEach(LlmApiType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("接口地址", text: $targetUrl, prompt: Text("https://api.openai.com/v1"))
                    .disableAutocorrection(true)
                TextField("API 密钥", text: $apiKey, prompt: Text("sk-..."))
                    .disableAutocorrection(true)
                TextField("模型", text: $model, prompt: Text("例如 gpt-4o"))
                    .disableAutocorrection(true)
            }
            .padding(.horizontal)

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEdit ? "保存" : "添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .onAppear {
            if case .edit(let m) = mode {
                alias = m.alias
                targetUrl = m.targetUrl
                apiKey = m.apiKey
                model = m.model
                apiType = m.apiType
            }
        }
    }

    private func save() {
        let mapping = LlmModelMapping(
            alias: alias.trimmingCharacters(in: .whitespaces),
            targetUrl: targetUrl.trimmingCharacters(in: .whitespaces),
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            model: model.trimmingCharacters(in: .whitespaces),
            apiType: apiType
        )
        if isEdit {
            appState.updateLlmMapping(originalAlias: originalAlias!, mapping: mapping)
        } else {
            appState.addLlmMapping(mapping)
        }
        dismiss()
    }
}
