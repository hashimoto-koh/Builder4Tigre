# libtigre_julia Build Design Specification (`docs/build-design.md`)

This specification defines the build inputs, outputs, ABI contracts, and platform requirements for reproducibly building `libtigre_julia`, the native C/CUDA shared library used by [Tigre.jl](https://github.com/hashimoto-koh/Tigre.jl), with BinaryBuilder.jl for distribution as `Tigre_jll`.

---

## 1. Source References and Pinned Revisions (Source Manifest)

### 1.1 Tigre.jl
- **Repository**: `https://github.com/hashimoto-koh/Tigre.jl`
- **Investigation HEAD Commit**: `da939625f5934c181c1b68f8f03c9922b64f7f71`
  - Commit message: `build(deps): bump upstream pinned commit to 81b6be2c and drop merged PICCS patch`

### 1.2 Upstream CERN/TIGRE
- **Repository**: `https://github.com/CERN/TIGRE.git`
- **Pinned Commit (Ref)**: `81b6be2cc12ee630d36cba941e111ba14ba34c7c`
- **Archive URL**: `https://github.com/CERN/TIGRE/archive/81b6be2cc12ee630d36cba941e111ba14ba34c7c.tar.gz`
- **Archive SHA256**: `8e757c629982285a77d01e136f688ec3f659adb54bbfce91f48dc39f633fdc4a`

---

## 2. Source Layout and Application Procedure

### 2.1 Upstream Sources (`Common/CUDA`)
The 15 source files required for current Julia integration:
1. `projection.cpp`
2. `TIGRE_common.cpp` (*Note: overwritten by overlay*)
3. `GpuIds.cpp`
4. `gpuUtils.cu`
5. `Siddon_projection.cu`
6. `Siddon_projection_parallel.cu`
7. `ray_interpolated_projection.cu`
8. `ray_interpolated_projection_parallel.cu`
9. `voxel_backprojection.cu`
10. `voxel_backprojection2.cu`
11. `voxel_backprojection_parallel.cu`
12. `GD_TV.cu`
13. `GD_AwTV.cu`
14. `tv_proximal.cu`
15. `PICCS.cu`

### 2.2 Overlays
Files that overwrite upstream files of the same name under `Common/CUDA/`:
| File Path (Source) | Target File | SHA256 |
|---|---|---|
| `deps/wrapper/overlay/TIGRE_common.hpp` | `Common/CUDA/TIGRE_common.hpp` | `9db1ef477613ff86b42036f03b2a88ca2992c1976ac1157152f8c16a04df8fb2` |
| `deps/wrapper/overlay/TIGRE_common.cpp` | `Common/CUDA/TIGRE_common.cpp` | `7cd1ff4217f8999c381acbf487508ff2ccb5884f79d66e9f1063cfb36ebbe546` |

- **Purpose**: Replaces C++ internal MATLAB/Python exception handling (`mexErrMsgTxt` or Python C-API calls) with thread-safe error buffer recording for Julia.

### 2.3 Julia-specific Shim / Runtime
Files implementing the Julia `ccall` boundary and C ABI:
| File Path | Role | SHA256 |
|---|---|---|
| `deps/wrapper/include/tigre_julia_shim.h` | Public C ABI header (structs, enums, function declarations) | `85c79eebd88675bf98fdb0d18b0de6573205ec6cfb7d7839b6188eb68f733e89` |
| `deps/wrapper/include/tigre_julia_runtime.hpp` | Internal thread-safe error holding runtime header | `4509e84eb595e2aad3d8af96a809571b679b4ec7f4d8068fd20863dc59d85d58` |
| `deps/wrapper/src/tigre_julia_runtime.cpp` | Error message buffer implementation | `d3f10a42746333a7bf81cd8161d21274f1b80ad66d5d2032aecd4fb5e0e5a15b` |
| `deps/wrapper/src/tigre_julia_shim.cpp` | C ABI shim implementation (`extern "C"` exports) | `b662c927affce84b276f73f858ccbdc9f26ae583997a8463c0dd12dfd05d5068` |

### 2.4 Patches
- As of commit `da939625f5934c181c1b68f8f03c9922b64f7f71`, upstream commit `81b6be2c` has merged the PICCS fix, so **currently 0 patches need to be applied**.

---

## 3. Compiler Flags and Build Specifications

### 3.1 Compilation Command Baseline
```bash
nvcc --shared -O3 --std=c++14 \
     --expt-relaxed-constexpr \
     --cudart shared \
     -Xcompiler=-fPIC \
     -Xlinker=--allow-multiple-definition \
     -DIS_FOR_JULIA_TIGRE \
     -ICommon/CUDA \
     -Iwrapper/include \
     -I${CUDA_HOME}/include \
     -L${CUDA_HOME}/lib64 -lcudart \
     -o libtigre_julia.so \
     ${ARCH_FLAGS} \
     ${SOURCES}
```

### 3.2 Linker and Dependency Analysis
- **Linked Target**: `libcudart.so`
- **Not Linked**: `libcuda.so` (provided by the host NVIDIA driver at runtime; must not be linked at build time)
- **C++ Exception Boundary**: To prevent C++ exceptions from crossing the C ABI boundary, all shim functions wrap operations in `try ... catch` and return integer status codes (`TigreJuliaStatus`).

---

## 4. C ABI Contract and Struct Layout

### 4.1 Geometry Structure (`TigreJuliaGeometry` / `CGeometry`)
A 28-field layout fully compatible with Julia's `struct CGeometry`:
```c
typedef struct TigreJuliaGeometry {
    int nVoxelX;               // int32
    int nVoxelY;               // int32
    int nVoxelZ;               // int32
    float sVoxelX;             // float32
    float sVoxelY;             // float32
    float sVoxelZ;             // float32
    float dVoxelX;             // float32
    float dVoxelY;             // float32
    float dVoxelZ;             // float32
    int nDetecU;               // int32
    int nDetecV;               // int32
    float sDetecU;             // float32
    float sDetecV;             // float32
    float dDetecU;             // float32
    float dDetecV;             // float32
    const float* offOrigX;     // Ptr{Float32} (angles-length array)
    const float* offOrigY;     // Ptr{Float32}
    const float* offOrigZ;     // Ptr{Float32}
    const float* DSO;          // Ptr{Float32}
    const float* offDetecU;    // Ptr{Float32}
    const float* offDetecV;    // Ptr{Float32}
    const float* DSD;          // Ptr{Float32}
    const float* dRoll;        // Ptr{Float32}
    const float* dPitch;       // Ptr{Float32}
    const float* dYaw;         // Ptr{Float32}
    const float* COR;          // Ptr{Float32}
    float accuracy;            // float32
    int mode;                  // int32 (0: cone, 1: parallel)
} TigreJuliaGeometry;
```

### 4.2 Exported 12 C ABI Functions
| Function Name | Arguments Summary | Return Value |
|---|---|---|
| `tigre_julia_ax` | `volume, geo, angles, nangles, proj_type, gpu_ids, gpu_cnt, out` | `int` (status code) |
| `tigre_julia_atb` | `proj, geo, angles, nangles, backproj_type, gpu_ids, gpu_cnt, out` | `int` (status code) |
| `tigre_julia_min_tv` | `vol, nx, ny, nz, alpha, maxiter, gpu_ids, gpu_cnt, out` | `int` (status code) |
| `tigre_julia_awmin_tv` | `vol, nx, ny, nz, alpha, maxiter, delta, gpu_ids, gpu_cnt, out` | `int` (status code) |
| `tigre_julia_tvdenoise` | `vol, nx, ny, nz, lambda, spacing_xyz, maxiter, gpu_ids, gpu_cnt, out` | `int` (status code) |
| `tigre_julia_piccs_tv` | `vol, prior, nx, ny, nz, alpha, ratio, maxiter, gpu_ids, gpu_cnt, out` | `int` (status code) |
| `tigre_julia_get_gpu_count` | `void` | `int` (GPU count) |
| `tigre_julia_get_gpu_name` | `device_id, char* name, size_t len` | `int` (status code) |
| `tigre_julia_clear_last_error`| `void` | `void` |
| `tigre_julia_last_error_message` | `void` | `const char*` |
| `tigre_julia_last_error_tag` | `void` | `const char*` |
| `tigre_julia_error_string` | `int status` | `const char*` |

---

## 5. CUDA / Platform Requirements

### 5.1 Initial Target
- **OS / ABI**: Linux x86_64 (`x86_64-linux-gnu`)
- **Hardware Verification GPU**: NVIDIA GeForce RTX 3090 (Compute capability `sm_86`)
- **CUDA Version**: CUDA 12.x family (Yggdrasil `CUDA_SDK_jll` + `CUDA_Runtime_jll`)

### 5.2 Yggdrasil Integration Strategy
- Platform augmentation using Yggdrasil's `platforms/cuda.jl`:
  - `CUDA_SDK_jll` as `BuildDependency`.
  - `CUDA_Runtime_jll` as runtime `Dependency`.
- Code generation flags:
  - SASS for primary target architectures (`sm_70`, `sm_75`, `sm_80`, `sm_86`, `sm_89`, `sm_90`).
  - PTX for forward compatibility (`compute_86`).

---

## 6. Licenses and Distribution Conditions

- **TIGRE**: BSD 3-Clause License (Copyright 2015, University of Bath and CERN)
- **Tigre.jl / Wrapper**: BSD 3-Clause License (Copyright 2024-2026, Koh Hashimoto and Tigre.jl contributors)
- **NVIDIA CUDA Runtime**: Follows the redistribution conditions for redistributable libraries (`libcudart`) under the NVIDIA Software License Agreement.
- Generated JLL packages bundle `LICENSE` / `NOTICE` containing all license texts and copyright statements.

---

## 7. BinaryBuilder Recipe Execution Results (Phase 2 Verification)

- **Execution Command**: `julia --startup-file=no --project=. build_tarballs.jl --verbose`
- **Target Platform**: `Platform("x86_64", "linux"; libc="glibc", cuda="12.4")`
- **Output Artifact**: `products/Tigre.v2.7.0.x86_64-linux-gnu-cuda+12.4.tar.gz`
  - **Tree Hash**: `07a661d5e4cbd7b53f5b4716b212eaba26ff17f3`
  - **SHA256**: `c90553f2921deaa61c6e44c0e82c051a3aacc0ad177362739c433c854a9a218e`
  - **Extracted Contents**: `lib/libtigre_julia.so` (~4.5 MB), `share/licenses/Tigre/LICENSE.txt` (~1.6 KB)
- **Binary Structure Inspection (`readelf -d`)**:
  - `SONAME`: `libtigre_julia.so`
  - `RUNPATH`: `$ORIGIN/../cuda/lib`
  - `NEEDED`: `libcudart.so.12`, `libstdc++.so.6`, `libc.so.6`, `libm.so.6`, `libgcc_s.so.1`, `ld-linux-x86-64.so.2`
- **Functional Verification**:
  - Ran `test/symbols.jl` (verifying all 12 C ABI symbols) and `test/smoke.jl` (dlopen, error string query, RTX 3090 device detection) on extracted `libtigre_julia.so`; all 20 checks PASSED.
- **Issues Encountered & Resolved**:
  1. **Source Format**: GitHub automatic tarballs are rejected by BinaryBuilderBase due to non-deterministic compression; resolved by using an immutable `GitSource`.
  2. **Dynamic Linking**: nvcc defaults to static cudart (`-lcudart_static`); resolved by passing `--cudart shared` so it links against `libcudart.so.12`.

---

## 8. JLL Package Generation and Standalone Validation Results (Phase 3 Verification)

- **Generation Command**: `julia --startup-file=no --project=. build_tarballs.jl --skip-build --deploy="local"`
- **Generated JLL Package**: `~/.julia/dev/Tigre_jll` (Version: `v2.7.0+0`)
  - Bound tree-sha1 `07a661d5e4...` and local tarball URL in `Artifacts.toml`.
- **Standalone Validation Environment (`test/jll_test_env`)**:
  - Created a clean separate environment, registered `Tigre_jll` via `develop`, and executed `test/test_jll.jl`.
  - **Load Verification**: `Tigre_jll.is_available() == true`
  - **Artifact Path**: `~/.julia/artifacts/07a661d5e4cbd7b53f5b4716b212eaba26ff17f3/lib/libtigre_julia.so`
  - **Symbol Verification**: All 12 C ABI symbols resolved via `dlsym`.
  - **Smoke Tests**: `tigre_julia_error_string(0)` => `"success"`, `tigre_julia_get_gpu_count()` => `1`, `tigre_julia_get_gpu_name(0)` => `"NVIDIA GeForce RTX 3090"`. All 20 tests PASSED.
- **ABI / Version Compatibility Inspection (`readelf --version-info`)**:
  - Maximum required GLIBC version: `GLIBC_2.14` (ensuring compatibility across a wide range of Linux distributions)
  - C++ Runtime Requirements: `GLIBCXX_3.4.21`, `CXXABI_1.3.9`
  - Dynamic Library Dependencies: `libcudart.so.12` only (CUDA Runtime provided via `CUDA_Runtime_jll`)
- **Operational Requirements**:
  - No `nvcc` or CUDA Toolkit required on the host system.
  - GPU kernels execute immediately in any environment with an NVIDIA Driver compatible with CUDA 12.
