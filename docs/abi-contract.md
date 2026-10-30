# C ABI Contract Specification (`docs/abi-contract.md`)

This specification defines the C ABI contract between the Julia package `Tigre.jl` and the native shared library `libtigre_julia`.

---

## 1. Core Principles

1. **Pure C ABI (`extern "C"`)**:
   - All exported functions are declared `extern "C"` to prevent C++ name mangling.
   - Calling conventions strictly adhere to the standard C calling convention for the target platform (System V AMD64 ABI on Linux x86_64).

2. **Complete Exception Shielding**:
   - Under no circumstances may C++ exceptions (`std::exception`, CUDA runtime errors, internal throws) cross the C ABI boundary.
   - All shim entry points encapsulate operations within a top-level `try ... catch` block, return integer status codes, and store detailed error diagnostics in an internal thread-local buffer.

3. **Memory Ownership**:
   - Memory allocation and deallocation for volume buffers (`volume`) and projection arrays (`projections`) are managed exclusively by the Julia runtime.
   - The native library reads and writes memory strictly through the supplied pointers.

---

## 2. Data Structures and Memory Layout

### 2.1 Geometry Structure `TigreJuliaGeometry`
A 28-member struct with exact 1:1 mapping to Julia's `Tigre.CGeometry`:

```c
typedef struct TigreJuliaGeometry {
    int nVoxelX;               // +0   (int32, 4 bytes)
    int nVoxelY;               // +4   (int32, 4 bytes)
    int nVoxelZ;               // +8   (int32, 4 bytes)
    float sVoxelX;             // +12  (float32, 4 bytes)
    float sVoxelY;             // +16  (float32, 4 bytes)
    float sVoxelZ;             // +20  (float32, 4 bytes)
    float dVoxelX;             // +24  (float32, 4 bytes)
    float dVoxelY;             // +28  (float32, 4 bytes)
    float dVoxelZ;             // +32  (float32, 4 bytes)
    int nDetecU;               // +36  (int32, 4 bytes)
    int nDetecV;               // +40  (int32, 4 bytes)
    float sDetecU;             // +44  (float32, 4 bytes)
    float sDetecV;             // +48  (float32, 4 bytes)
    float dDetecU;             // +52  (float32, 4 bytes)
    float dDetecV;             // +56  (float32, 4 bytes)
    // Enters 8-byte alignment boundary on 64-bit platforms
    const float* offOrigX;     // +64  (pointer, 8 bytes)
    const float* offOrigY;     // +72  (pointer, 8 bytes)
    const float* offOrigZ;     // +80  (pointer, 8 bytes)
    const float* DSO;          // +88  (pointer, 8 bytes)
    const float* offDetecU;    // +96  (pointer, 8 bytes)
    const float* offDetecV;    // +104 (pointer, 8 bytes)
    const float* DSD;          // +112 (pointer, 8 bytes)
    const float* dRoll;        // +120 (pointer, 8 bytes)
    const float* dPitch;       // +128 (pointer, 8 bytes)
    const float* dYaw;         // +136 (pointer, 8 bytes)
    const float* COR;          // +144 (pointer, 8 bytes)
    float accuracy;            // +152 (float32, 4 bytes)
    int mode;                  // +156 (int32, 4 bytes) - 0: cone, 1: parallel
} TigreJuliaGeometry;
```

### 2.2 Strided Layout for Array Data
Julia's multi-dimensional arrays (column-major / Fortran order) are passed as contiguous memory pointers:
- **Volume**: `volume[x, y, z]` (3D: X is the fastest-varying axis, Z is the slowest-varying axis)
- **Projections**: `projections[u, v, angle]` (3D: U is the fastest-varying axis, angle is the slowest-varying axis)

---

## 3. Exported Functions (12 Symbols)

### 3.1 Forward and Backward Projections
```c
int tigre_julia_ax(
    const float* volume,
    const TigreJuliaGeometry* geometry,
    const float* angles,
    int nangles,
    int projection_type,      // 0: siddon, 1: interpolated
    const int* gpu_ids,
    int gpu_count,
    float* projections_out);

int tigre_julia_atb(
    const float* projections,
    const TigreJuliaGeometry* geometry,
    const float* angles,
    int nangles,
    int backprojection_type,  // 0: fdk, 1: matched
    const int* gpu_ids,
    int gpu_count,
    float* volume_out);
```

### 3.2 Total Variation (TV) Regularization and Denoising
```c
int tigre_julia_min_tv(
    const float* volume,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float alpha, int maxiter,
    const int* gpu_ids, int gpu_count,
    float* volume_out);

int tigre_julia_awmin_tv(
    const float* volume,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float alpha, int maxiter, float delta,
    const int* gpu_ids, int gpu_count,
    float* volume_out);

int tigre_julia_tvdenoise(
    const float* volume,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float lambda, const float* spacing_xyz, int maxiter,
    const int* gpu_ids, int gpu_count,
    float* volume_out);

int tigre_julia_piccs_tv(
    const float* volume, const float* prior,
    int nVoxelX, int nVoxelY, int nVoxelZ,
    float alpha, float ratio, int maxiter,
    const int* gpu_ids, int gpu_count,
    float* volume_out);
```

### 3.3 GPU Queries
```c
int tigre_julia_get_gpu_count(void);
int tigre_julia_get_gpu_name(int device_id, char* name, size_t name_len);
```

### 3.4 Error Handling
```c
void tigre_julia_clear_last_error(void) noexcept;
const char* tigre_julia_last_error_message(void) noexcept;
const char* tigre_julia_last_error_tag(void) noexcept;
const char* tigre_julia_error_string(int status);
```

### 3.5 Status Codes
| Constant | Value | Description |
|---|---|---|
| `TIGRE_JULIA_STATUS_SUCCESS` | `0` | Success |
| `TIGRE_JULIA_STATUS_INVALID_ARGUMENT` | `64` | Invalid geometry parameter or null pointer |
| `TIGRE_JULIA_STATUS_RUNTIME_ERROR` | `65` | CUDA runtime error or internal exception |
