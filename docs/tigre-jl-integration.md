# Tigre.jl Integration Verification and Patch Specification (`docs/tigre-jl-integration.md`)

This specification documents the integration design, patch details, and hardware verification results for integrating `Tigre_jll` (built with BinaryBuilder) into `Tigre.jl`, enabling instant GPU reconstruction without requiring local compilation.

---

## 1. Core Integration Principles

1. **Zero Breaking Changes**:
   - The public API of `Tigre.jl` (`Ax`, `Atb`, reconstruction algorithms, geometry definitions, return types, and array dimensions) remains 100% identical.
   - The existing local build path (`deps/build.jl`) is preserved as a fallback for developers.

2. **Resolution Priority Chain**:
   Resolution order for `native_library_path()`:
   1. Explicit environment variable overrides (`LIBTIGRE_PATH` / `TIGRE_NATIVE_PATH`)
   2. JLL artifact path (`Tigre_jll.libtigre_julia_path`) when `Tigre_jll.is_available()` is `true`
   3. Local build artifact `deps/usr/lib/libtigre_julia.so`

3. **Diagnostics Update**:
   - `library_status()` reports `backend = :jll | :source`.
   - `doctor.jl` clearly indicates when the JLL backend is active (`"JLL backend active (no local nvcc needed)"`).

---

## 2. Numerical Regression Results on Hardware GPU (RTX 3090, `sm_86`)

Using `test/integration_test.jl`, rigorous numerical regression testing was performed for all 12 algorithms in `Tigre.jl` using `libtigre_julia.so` loaded via JLL against known golden regression fixtures.

| Test Item | Algorithm Type | Result | Tolerance | Status |
|---|---|---|---|---|
| 1. `Ax` | Cone-beam forward projection (Siddon) | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 2. `Atb` | Cone-beam backprojection (Matched) | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 3. `FDK` | FDK reconstruction (Hann filter, Wang padding) | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 4. `SART` | SART iterative reconstruction (1 iter) | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 5. `FISTA` | FISTA reconstruction (with TV regularization) | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 6. `LSMR` | LSMR iterative solver (1 iter) | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 7. `Hybrid FLSQR TV` | Hybrid FLSQR + TV | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 8. `PICCS` | Prior image constrained compressed sensing | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 9. `Parallel FBP` | Parallel-beam FBP (Hann filter) | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 10. `MLEM` | Statistical MLEM reconstruction | Exact match (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 11. `PCSD` | POCS TV reconstruction | Exact match (sum, norm, min, max, samples) | `atol=2e-4`, `rtol=1e-5` | ✅ PASS |
| 12. `AwPCSD` | Adaptive-weighted POCS TV | Exact match (sum, norm, min, max, samples) | `atol=2e-4`, `rtol=1e-5` | ✅ PASS |

**Total: 120 / 120 test checks PASSED (12.4s execution time)**

---

## 3. Patch Application Guide (`Tigre.jl`)

To apply `patches/tigre_jl_jll_integration.patch` to a branch of `Tigre.jl`:

```bash
cd /path/to/Tigre.jl
git checkout -b feature/tigre-jll
git apply /path/to/Builder4Tigre/patches/tigre_jl_jll_integration.patch
```
