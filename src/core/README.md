# core

Platform-independent virtualization core shared by the Windows, macOS, and Linux runtimes.
Everything here is portable C++ and links into `agentsphere-vm-runtime` regardless of host OS.

## Modules

| Directory | Purpose |
|---|---|
| [`vmm/`](vmm) | VM orchestration: [`Vm`](vmm/vm.h) lifecycle, [`AddressSpace`](vmm/address_space.h) for PIO/MMIO dispatch, vCPU I/O loop, and the abstract [`HypervisorVm`](vmm/hypervisor_vm.h) / [`HypervisorVCpu`](vmm/hypervisor_vcpu.h) interfaces that platform backends implement. |
| [`arch/`](arch) | Guest machine models. `x86_64/` handles the Linux 64-bit boot protocol, ACPI tables, and the x86 machine glue; `aarch64/` handles the ARM boot flow, FDT generation, and the PL011 UART. |
| [`device/`](device) | Emulated devices shared across backends: serial (16550), i8254 PIT, CMOS RTC, x86 Local APIC / I/O APIC / i8259 PIC, aarch64 GICv3, ACPI PM registers, PCI host bridge, and the full VirtIO MMIO stack (blk, net, gpu, input, serial, snd, fs). |
| [`disk/`](disk) | Disk image backends for raw and qcow2 (with zlib/zstd cluster decompression) plus a qcow2 consistency checker. |
| [`net/`](net) | lwIP-based user-mode NAT backend: DHCP server, TCP/UDP NAT, ICMP relay, host-forward and guest-forward. |
| [`guest_agent/`](guest_agent) | qemu-guest-agent protocol handler used for VM lifecycle and shutdown coordination. |
| [`vdagent/`](vdagent) | SPICE vdagent protocol handler (bidirectional host/guest clipboard). |
| [`util/`](util) | Small cross-platform helpers, e.g. the high-resolution timer: `hires_timer_win.cpp` on Windows, `hires_timer_mac.cpp` on macOS, and the libuv-based `hires_timer_uv.cpp` fallback on Linux (and as the common fallback elsewhere). |

## Platform boundary

Anything OS-specific (hypervisor backend, console I/O, shared framebuffer transport)
lives under [`src/platform/`](../platform). The core talks to those implementations
only through the abstract interfaces in [`vmm/`](vmm), so each device and arch module
stays host-agnostic.
