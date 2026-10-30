# Hardware Integration Testing Guide (`test/integration.md`)

This document provides instructions for executing hardware integration testing with `Tigre.jl` using `libtigre_julia` built by `Builder4Tigre` on a machine equipped with an NVIDIA GPU (GeForce RTX 3090, `sm_86`).

---

## 1. Prerequisites

- **Host OS**: Linux x86_64
- **NVIDIA Driver**: 550 or newer (CUDA 12.x compatible driver)
- **GPU**: NVIDIA GeForce RTX 3090 (`sm_86`)
- **Tigre.jl Repository**: `/home/jov/git/prj/Tigre.jl/`

---

## 2. Integration Verification Steps

### Step 1: Library Symbols and Smoke Tests
```bash
julia --startup-file=no --project=. test/symbols.jl
julia --startup-file=no --project=. test/smoke.jl
```

### Step 2: Direct Diagnostic Verification from Tigre.jl
Run `Tigre.jl`'s diagnostic API pointing to either the explicit library path (`LIBTIGRE_PATH`) or the generated JLL artifact path:

```bash
cd /home/jov/git/prj/Tigre.jl
julia --startup-file=no --project=. doctor.jl
```

Expected output:
- `available: true`
- `gpu_probe: ok` with RTX 3090 detected

### Step 3: Numerical Regression Testing for Projections and Reconstruction
Run `Tigre.jl`'s full test suite to confirm numerical consistency within specified tolerances (`atol`/`rtol`):

```bash
cd /home/jov/git/prj/Tigre.jl
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'
```

Alternatively, run the standalone verification suite:
```bash
julia --startup-file=no --project=. test/integration_test.jl
```

Key verification areas:
1. `Ax`: Siddon and Interpolated forward projections (Cone-beam / Parallel-beam)
2. `Atb`: FDK and Matched backprojections
3. `TV`: Total Variation regularizers (`tigre_julia_min_tv`, `tigre_julia_awmin_tv`)
4. `PICCS`: Prior image constrained compressed sensing reconstruction
