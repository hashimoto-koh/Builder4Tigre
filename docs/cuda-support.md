# CUDA Support Specification and Architecture Strategy (`docs/cuda-support.md`)

This document defines the supported CUDA Toolkit versions, GPU architectures (Compute Capability / SASS), PTX fallback strategy, and driver compatibility policies for building `libtigre_julia`.

---

## 1. Core Principles of Support Policy

1. **Separation of Host NVIDIA Driver and CUDA Runtime**:
   - `libtigre_julia` dynamically links only against `libcudart` (CUDA Runtime API).
   - It does not link against `libcuda.so` (CUDA Driver API); driver calls are resolved at runtime from the host system's NVIDIA Driver.
   - The execution host requires an NVIDIA Display / Compute Driver meeting the requirements of the targeted CUDA version.

2. **Initial Target and Hardware Validation Environment**:
   - **Development & Hardware Verification Target**: NVIDIA GeForce RTX 3090 (`sm_86`)
   - **Host Driver**: 570.211.01 (CUDA 12.8 compatible)
   - **Initial Build Target**: CUDA 12.x family (via Yggdrasil's `CUDA_SDK_jll` and `CUDA_Runtime_jll`)

---

## 2. Target GPU Architectures and Code Generation Strategy

Generating machine binary code (SASS) for every GPU architecture simultaneously risks bloating the shared library size to multiple gigabytes.
Therefore, SASS is compiled for major active architectures, supplemented with a PTX virtual assembly target for JIT compilation on future GPU generations.

### 2.1 Targeted Compute Capabilities (SASS)

| Architecture | Compute Capability | Representative GPUs | Build Flag |
|---|---|---|---|
| Volta | `sm_70` | Titan V, V100 | SASS generation (`-gencode=arch=compute_70,code=sm_70`) |
| Turing | `sm_75` | RTX 2080, T4 | SASS generation (`-gencode=arch=compute_75,code=sm_75`) |
| Ampere | `sm_80` | A100 | SASS generation (`-gencode=arch=compute_80,code=sm_80`) |
| Ampere | `sm_86` | RTX 3090 (Primary test hardware), RTX 3080 | SASS generation (`-gencode=arch=compute_86,code=sm_86`) |
| Ada Lovelace | `sm_89` | RTX 4090, RTX 4080, L40 | SASS generation (`-gencode=arch=compute_89,code=sm_89`) |
| Hopper | `sm_90` | H100 | SASS generation (`-gencode=arch=compute_90,code=sm_90`) |

### 2.2 PTX Fallback
- To ensure forward compatibility on future GPU architectures (e.g. Blackwell) via runtime driver JIT compilation, a PTX virtual architecture code is included:
  `-gencode=arch=compute_86,code=compute_86` (or the highest compute capability supported by the target CUDA Toolkit version).

---

## 3. Integration with Yggdrasil `platforms/cuda.jl`

In accordance with Yggdrasil's CUDA platform augmentation mechanism, artifacts are built with CUDA platform tags:

```julia
# Example: targeting Linux x86_64 with CUDA 12 series
Platform("x86_64", "linux"; cuda="12.4")
```

- **Build Dependency**: `CUDA_SDK_jll` (supplies headers and nvcc toolchain at compile time)
- **Runtime Dependency**: `CUDA_Runtime_jll` (supplies `libcudart` at runtime)

---

## 4. Runtime Error Handling

When `libtigre_julia` is loaded in an environment without a GPU or without an appropriate NVIDIA driver:
- `Libdl.dlopen` succeeds, allowing library diagnostics and export symbol inspection.
- `tigre_julia_get_gpu_count()` safely returns `0`.
- If an actual kernel call (such as `tigre_julia_ax`) is invoked, CUDA runtime errors are caught safely, returning `TIGRE_JULIA_STATUS_RUNTIME_ERROR` with a descriptive message (e.g., `cudaErrorNoDevice` or `cudaErrorInsufficientDriver`) available via `tigre_julia_last_error_message()` without crashing or aborting the process.
