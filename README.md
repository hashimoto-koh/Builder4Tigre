# Builder4Tigre

`Builder4Tigre` manages the build recipes, patches, and verification assets for building the native C/CUDA backend shared library (`libtigre_julia`) of [Tigre.jl](https://github.com/hashimoto-koh/Tigre.jl) using [BinaryBuilder.jl](https://github.com/JuliaPackaging/BinaryBuilder.jl), ultimately packaging and distributing it as the official JLL package `Tigre_jll`.

This project is an unofficial packaging pipeline for [Tigre.jl](https://github.com/hashimoto-koh/Tigre.jl), which interfaces with the native C/CUDA reconstruction engines of [TIGRE](https://github.com/CERN/TIGRE) (Tomographic Iterative GPU-based Reconstruction Toolbox).

> [!NOTE]
> This project is **not** affiliated with, endorsed by, or maintained by CERN, the University of Bath, or the upstream TIGRE contributors.
>
> The foundational TIGRE C/CUDA reconstruction algorithms were developed by the University of Bath and CERN contributors and are distributed under the BSD 3-Clause License. We express our deep respect and sincere gratitude to the original authors and maintainers for making TIGRE open source and advancing accessible tomographic reconstruction.

---

## Purpose

Previously, using `Tigre.jl` required compiling the native CUDA backend locally via `Pkg.build("Tigre")`, necessitating a local CUDA toolkit and `nvcc` compiler on the user's host machine.
The goal of this repository is to build reproducible relocatable binaries for `libtigre_julia` and submit the build recipe to the official community build tree [Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil). This enables distributing precompiled binaries as `Tigre_jll`, allowing Julia users to run GPU-accelerated tomographic reconstructions with only an appropriate NVIDIA driver installed—without requiring a local CUDA development environment or compiler.

> [!NOTE]
> **Naming Distinctions**:
> - `Builder4Tigre`: This repository (manages build recipes, patches, verification assets, and migration plans).
> - `Tigre_jll`: The auto-generated Julia binary wrapper package created and published by Yggdrasil.
> - `Tigre.jl`: The high-level Julia tomographic reconstruction package containing algorithms, public APIs, and user interfaces.

---

## Repository Layout

```text
Builder4Tigre/
├── bundled/                 # Shims, runtime, overlays, and patches bundled into the build
│   ├── wrapper/             # Julia-specific C ABI shim and runtime implementations
│   ├── overlay/             # Replacement source files overriding upstream Common/CUDA
│   └── patches/             # Upstream unified diff patches (currently 0)
├── docs/                    # Technical specifications and design documents
│   ├── build-design.md      # Build design specification and source manifest
│   ├── cuda-support.md      # CUDA compatibility, toolkit versions, and GPU architecture strategy
│   ├── abi-contract.md      # C ABI contract and struct layout definitions
│   ├── release-process.md   # Release lifecycle and Yggdrasil PR process
│   └── tigre-jl-integration.md # Tigre.jl integration design and numerical regression report
├── sources/                 # Source manifest and automated checksum verification scripts
│   ├── manifest.toml        # Pinned commits, archive URLs, and SHA256 checksums
│   └── verify_sources.jl    # Source checksum verification script
├── test/                    # Validation and regression test suites
│   ├── smoke.jl             # Basic dlopen and GPU device query smoke test
│   ├── symbols.jl           # Verification of all 12 required exported C ABI symbols
│   ├── runtests.jl          # Master test suite runner
│   ├── test_jll.jl          # Standalone verification test for the generated Tigre_jll package
│   ├── integration_test.jl  # Numerical regression test running all 12 algorithms against fixtures
│   └── integration.md       # Hardware GPU integration testing guide
├── build_tarballs.jl        # BinaryBuilder.jl build recipe
├── LICENSE                  # BSD 3-Clause License
├── NOTICE.md                # Third-party notices and attributions
└── PLAN.md                  # Development milestone plan and progress tracker
```

---

## Reproducible Source Verification

All sources, overlays, and wrapper files are strictly pinned by cryptographic hashes (Git commit SHA and SHA256 checksums) to ensure deterministic and reproducible builds:

```bash
julia --startup-file=no --project=. sources/verify_sources.jl
```

---

## Testing

Run the master verification test suite:

```bash
julia --startup-file=no --project=. test/runtests.jl
```

---

## CUDA Support and Hardware Compatibility Matrix

`libtigre_julia` dynamically links only against `libcudart.so` (provided by `CUDA_Runtime_jll`). The CUDA Driver API (`libcuda.so`) is supplied by the host system at runtime.

### Supported Architectures (SASS + PTX)
| Architecture | Compute Capability | Representative GPUs | Build Flag |
|---|---|---|---|
| Volta | `sm_70` | Titan V, V100 | SASS generation |
| Turing | `sm_75` | RTX 2080, T4 | SASS generation |
| Ampere | `sm_80` | A100 | SASS generation |
| Ampere | `sm_86` | RTX 3090 (Primary test hardware), RTX 3080 | SASS generation |
| Ada Lovelace | `sm_89` | RTX 4090, RTX 4080, L40 | SASS generation |
| Hopper | `sm_90` | H100 | SASS generation |
| Forward Compatibility | `compute_86` | Future GPU architectures | PTX JIT compilation |

- **Host Driver Requirement**: NVIDIA driver version 550 or newer (CUDA 12.x compatible).
- **Host Compiler Requirement**: None. No local `nvcc` or CUDA Toolkit is needed to run `Tigre.jl` with `Tigre_jll`.

---

## Installation and Usage Workflow

### 1. Standard End-User Workflow (Post-Registration)
Once `Tigre_jll` is published in the Julia General registry and integrated into `Tigre.jl`:
```julia
using Pkg
Pkg.add("Tigre")
```
Julia will automatically download the precompiled binary artifact matching your system's architecture and CUDA runtime. `using Tigre` will immediately be ready to run GPU reconstructions.

### 2. Developer Fallback and Local Build Policy
The traditional local build path via `deps/build.jl` is preserved in `Tigre.jl`:
- **Explicit Override**:
  ```bash
  export LIBTIGRE_PATH="/path/to/custom/libtigre_julia.so"
  ```
- **Local Compilation Fallback**:
  If the precompiled JLL is unavailable or a custom patch is being tested, running `Pkg.build("Tigre")` builds the native library locally into `deps/usr/lib/libtigre_julia.so`.

---

## Troubleshooting and Diagnostics

### Diagnostic Verification (`doctor.jl`)
In `Tigre.jl`, execute the diagnostic probe:
```bash
julia --startup-file=no --project=. doctor.jl
```
Expected output with JLL active:
- `backend: jll`
- `available: true`
- `gpu_probe: ok` (detects GPU name, e.g. "NVIDIA GeForce RTX 3090")

### Common Issues
1. **No NVIDIA GPU or Driver Missing**:
   `Tigre_jll` loads successfully without errors, but `tigre_julia_get_gpu_count()` reports `0`. Running reconstruction will safely return error code `65` with `cudaErrorNoDevice` rather than crashing Julia.
2. **Preference Conflicts**:
   If CUDA runtime preferences are pinned globally, ensure `CUDA_Runtime_jll` preferences in `LocalPreferences.toml` are configured with `local = false` and `version = "12.4"`.

---

## Yggdrasil Contribution

The complete build recipe and bundled assets are staged under `yggdrasil/T/Tigre/`:
- [`yggdrasil/README.md`](yggdrasil/README.md) details instructions for submitting the Pull Request to [JuliaPackaging/Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil).

---

## License

The recipes, shims, and scripts in this repository are licensed under the [BSD 3-Clause License](LICENSE).
For upstream CERN/TIGRE copyright notices and NVIDIA CUDA redistribution disclosures, please refer to [NOTICE.md](NOTICE.md).
