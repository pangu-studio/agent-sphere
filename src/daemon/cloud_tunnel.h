#pragma once

#include "daemon/host_settings.h"
#include "daemon/llm_proxy.h"
#include "daemon/remote_webrtc.h"
#include "daemon/remote_session.h"
#include "daemon/runtime_manager.h"
#include "daemon/vm_store.h"

#include <atomic>
#include <chrono>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>

// Forward-declare OpenSSL types to keep SSL/TLS includes out of the header.
typedef struct ssl_st SSL;
typedef struct ssl_ctx_st SSL_CTX;

namespace tenbox::daemon {

class CloudTunnel {
public:
    CloudTunnel(DaemonConfig config, VmStore& store, RuntimeManager& runtime_manager);
    ~CloudTunnel();

    bool Start(std::string* error);
    void Stop();

private:
    struct DownloadJob {
        std::string job_id;
        std::string cache_id;
        std::string image_name;
        std::string status = "pending";
        std::string error;
        uint64_t downloaded_bytes = 0;
        uint64_t total_bytes = 0;
        uint64_t speed_bps = 0;
        uint64_t eta_seconds = 0;
        uint64_t started_at = 0;
        uint64_t updated_at = 0;
        bool cancel_requested = false;
        int current_pid = -1;
    };

    void ThreadMain();
    void TickMain();
    bool Connect(std::string* error);
    void Disconnect();
    bool SendJson(const nlohmann::json& value);
    bool ReadJson(nlohmann::json* value);
    // Plain or TLS read/write depending on `tls_enabled_`.
    bool TransportSend(const void* data, size_t size);
    bool TransportRecv(void* data, size_t size);
    nlohmann::json HelloPayload() const;
    void HandleDevicePaired(const nlohmann::json& payload);
    void HandleDevicePairInvalid();
    void HandleDeviceUnauthorized(const nlohmann::json& payload);
    nlohmann::json HandleRequest(const nlohmann::json& request);
    // Synchronous response is one of:
    //   - vms_running / update_disabled / apt_failed error envelope
    //     (rejected before apt got a chance to run),
    //   - {ok:true, accepted:true, from, to} ack (apt detached into
    //     a systemd transient scope; daemon will not see it again).
    // There is no follow-up envelope on this id: the apt process
    // lives in its own cgroup and the daemon may be SIGTERM'd by
    // postinst before apt finishes anyway. The console learns the
    // outcome by polling daemon_version in subsequent host ticks.
    nlohmann::json HandleHostUpdate(const std::string& id,
                                    const nlohmann::json& payload);
    nlohmann::json HostResourcesPayload() const;
    nlohmann::json VmResourcesSnapshot() const;
    void PushVmCreated(const VmRecord& record);
    void PushVmEdited(const VmRecord& record);
    void PushVmDeleted(const std::string& vm_id);
    void PushVmStateChanged(const std::string& vm_id, const VmRuntimeInfo& info);
    void PushImageCachedAdded(const std::string& cache_id, const std::string& image_name);
    void PushImageCachedRemoved(const std::string& cache_id);
    void PushDownloadProgress(const DownloadJob& job);
    void PushDownloadTerminal(const DownloadJob& job);
    // Buffer a batch of log lines from `RuntimeManager`. Drained by
    // `FlushLogBuffersLocked` either when 32 lines accumulate for a single VM
    // or when the tick thread fires the 200ms timer, whichever comes first.
    void EnqueueLogLines(const std::string& vm_id, const std::vector<std::string>& lines);
    void FlushLogBuffers();
    nlohmann::json VmListPayload() const;
    nlohmann::json ImageListPayload() const;
    nlohmann::json DeleteCachedImage(const nlohmann::json& payload);
    nlohmann::json StartImageDownload(const nlohmann::json& payload);
    nlohmann::json ImageDownloadList() const;
    nlohmann::json ImageDownloadStatus(const nlohmann::json& payload);
    nlohmann::json CancelImageDownload(const nlohmann::json& payload);
    nlohmann::json CreateRemoteSession(const std::string& vm_id, const nlohmann::json& payload);
    nlohmann::json ResizeRemoteSession(const std::string& vm_id, const nlohmann::json& payload);
    nlohmann::json CloseRemoteSession(const std::string& vm_id, const nlohmann::json& payload);
    nlohmann::json HandleRemoteSignal(const std::string& vm_id, const std::string& type, const nlohmann::json& payload);
    std::shared_ptr<WebRtcPeer> CreateRemotePeer(
        const std::string& session_id,
        const std::string& vm_id,
        PixelFormat preferred_video_format = PixelFormat::kYuv420p);
    void HandleDataChannelMessage(const std::string& vm_id, const nlohmann::json& message);
    void PublishRemoteCursor(const std::string& vm_id, nlohmann::json cursor);
    void PublishRemoteAudio(const std::string& vm_id, RemoteAudioChunk chunk);
    nlohmann::json CreateVm(const nlohmann::json& payload);
    nlohmann::json EditVm(const std::string& vm_id, const nlohmann::json& payload);
    nlohmann::json DeleteVm(const std::string& vm_id);
    nlohmann::json GetLlmProxySettings() const;
    nlohmann::json UpdateLlmProxySettings(const nlohmann::json& payload);

    DaemonConfig config_;
    VmStore& store_;
    RuntimeManager& runtime_manager_;
    std::thread thread_;
    std::thread tick_thread_;
    std::atomic<bool> running_{false};
    int fd_ = -1;
    // OpenSSL handles for wss://; both nullptr when running plain ws://.
    SSL_CTX* ssl_ctx_ = nullptr;
    SSL* ssl_ = nullptr;
    bool tls_enabled_ = false;
    // True only after the TLS handshake (if any) and the WebSocket upgrade
    // have completed and we are ready to send WS frames. The tick thread
    // and any other background producer must gate writes on this rather
    // than `fd_ >= 0`: with TLS the socket is alive long before SSL_write
    // can be safely called, and a stray frame written during the handshake
    // window lands on the wire as a bogus "Application Data" record that
    // Cloudflare answers with a fatal `unexpected_message` alert.
    std::atomic<bool> connected_{false};

    // VM list+watch subscription state. `current_sub_id_` is 0 when there is
    // no active subscription (daemon won't push vm.* delta events).  Set by the
    // vm.subscribe RPC handler AFTER the snapshot response is sent so deltas
    // are never delivered before the snapshot.  Reset to 0 in Disconnect().
    // `current_seq_` is reset to 0 on each new subscription and pre-incremented
    std::mutex send_mu_;
    std::string host_id_;
    // Pairing state: when device.token exists on disk we reconnect with the
    // long-lived token; otherwise we generate a fresh 8-digit pair_code at
    // each connect attempt and let the cloud emit `device.paired` to mint
    // the token. Both fields are guarded by `pair_mu_`.
    mutable std::mutex pair_mu_;
    std::string device_token_;
    std::string pair_code_;
    // Wall-clock seconds since epoch at construction. Stable across cloud
    // reconnects (a flapping WS does not reset uptime); used by
    // HostResourcesPayload to expose `daemon_uptime_seconds` so the console
    // can show "Daemon up 3h 12m" without a separate RPC.
    int64_t start_time_seconds_ = 0;
    RemoteSessionRegistry remote_sessions_;
    std::mutex remote_peers_mu_;
    std::unordered_map<std::string, std::shared_ptr<WebRtcPeer>> remote_peers_;

    nlohmann::json DownloadJobToJson(const DownloadJob& job) const;
    mutable std::mutex download_mu_;
    std::unordered_map<std::string, DownloadJob> download_jobs_;

    // Per-VM disk usage cache. DirectorySizeBytes walks the entire VM
    // directory recursively, so calling it on every vm.list / 30s tick is
    // expensive when VMs have multi-GB disk images. The TTL is short
    // enough that the console UI never sees stale-by-more-than-a-minute
    // numbers but long enough to skip walking the same trees over and
    // over.
    struct DiskUsageEntry {
        uint64_t bytes = 0;
        std::chrono::steady_clock::time_point at{};
    };
    uint64_t CachedDirectorySizeBytes(const std::string& path) const;
    // Drop the entry for `path` (called on vm.delete so the cache doesn't
    // accumulate dead VM dirs forever).
    void EvictDiskCacheEntry(const std::string& path);
    mutable std::mutex disk_cache_mu_;
    mutable std::unordered_map<std::string, DiskUsageEntry> disk_cache_;

    // Host-level settings (currently just the LLM reverse proxy). Loaded
    // lazily by Start() and re-saved by UpdateLlmProxySettings.
    mutable std::mutex host_settings_mu_;
    HostSettings host_settings_;

    // Owns the in-process LLM proxy server. Created lazily by Start()
    // when the persisted settings have at least one mapping (to avoid
    // grabbing a port we'd never use). UpdateLlmProxySettings hot-loads
    // new mappings and may relocate the listen port by Stop()/Start().
    std::unique_ptr<LlmProxyService> llm_proxy_;
    void EnsureLlmProxyForSettingsLocked(const LlmProxySettings& desired);

    // Per-VM log line buffer. Producer is `RuntimeManager::ReadLogs` (one
    // line at a time, fast path); consumer is `FlushLogBuffers`, which
    // serializes one `vm.logs.append` per VM with all queued lines.
    mutable std::mutex log_buffer_mu_;
    std::unordered_map<std::string, std::vector<std::string>> log_buffer_;
    static constexpr size_t kLogBatchMaxLines = 32;
    static constexpr int kLogFlushIntervalMs = 200;
};

}  // namespace tenbox::daemon
