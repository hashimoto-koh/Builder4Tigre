# Release Process Specification (`docs/release-process.md`)

This specification defines the formal release workflow for contributing the `libtigre_julia` build recipe to the community repository [JuliaPackaging/Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil) and integrating the resulting `Tigre_jll` package into [Tigre.jl](https://github.com/hashimoto-koh/Tigre.jl).

---

## 1. Distribution and Registration Principles

- **Official JLLs via Yggdrasil are the Standard**:
  The Julia General registry maintainers do not accept new manually generated JLL packages. Therefore, this repository (`Builder4Tigre`) serves as the staging and validation environment for recipes and patches, while official binary generation and registry publication occur via Pull Requests to Yggdrasil.
- **Repository Distinction**:
  - `hashimoto-koh/Builder4Tigre`: This development and validation repository.
  - `JuliaPackaging/Yggdrasil/T/Tigre/`: The official recipe directory in Yggdrasil.
  - `Tigre_jll`: The Julia package automatically built, tagged, and registered by Yggdrasil's CI/CD.

---

## 2. Release and Registration Procedure

### Step 1: Local Verification in `Builder4Tigre`
1. Ensure source revisions and SHA256 checksums in `sources/manifest.toml` are pinned and verified.
2. Confirm that `sources/verify_sources.jl` passes.
3. Build the artifact tarball locally using `build_tarballs.jl` inside the BinaryBuilder sandbox.
4. Run `test/symbols.jl` and `test/smoke.jl` against the generated `libtigre_julia.so` and ensure all tests pass.
5. Verify `Tigre.jl` numerical regression tests (Ax / Atb / TV) pass on target GPU hardware (`sm_86`).

### Step 2: Submitting a Pull Request to Yggdrasil
1. Fork `JuliaPackaging/Yggdrasil`.
2. Create the `T/Tigre/` directory with the following structure:
   ```text
   T/Tigre/
   ├── build_tarballs.jl
   └── bundled/
       ├── overlay/
       └── wrapper/
   ```
3. Ensure Yggdrasil CI builds (Linux / CUDA) succeed and obtain reviewer approvals for merging.
4. Yggdrasil will automatically generate `Tigre_jll` and register it in the Julia General registry.

### Step 3: Integration into `Tigre.jl`
1. Create a dedicated branch in `Tigre.jl` (e.g., `feature/tigre-jll`).
2. Add `Tigre_jll` to `[deps]` in `Project.toml`.
3. Update `src/bindings.jl` to prioritize loading `Tigre_jll.libtigre_julia`.
4. Retain the existing `deps/build.jl` (local source build path) as a developer fallback.
5. Confirm all tests pass on CI and GPU hardware, then submit and merge the PR.

---

## 3. Versioning Strategy

- **Upstream TIGRE Version**: e.g., `2.x.y`
- **JLL Build Number**: When updating only recipes or patches, increment the JLL build number (e.g., `v2.x.y+0`, `v2.x.y+1`).
- **Breaking ABI Changes**: If the C ABI or `TigreJuliaGeometry` structure changes, coordinate version bumps carefully following `Tigre.jl`'s minor/major version compatibility policies.

---

## 4. Version and ABI Correspondence Matrix

| `Tigre_jll` Version | Upstream CERN/TIGRE Ref | Wrapper SHA | C ABI Symbols | `TigreJuliaGeometry` Layout | Compatible `Tigre.jl` |
|---|---|---|---|---|---|
| `v2.7.0+0` | `81b6be2cc12ee630d36cba941e111ba14ba34c7c` | `da939625f` | 12 symbols (`ax`, `atb`, TV, piccs, error/device APIs) | 28 fields (cone/parallel, offsets, angles) | `v0.1.0`+ |

---

## 5. Upstream Synchronization Protocol

When upstream CERN/TIGRE tags a new release or updates `master`:
1. **Update Manifest**: Update `upstream.pinned_commit`, `upstream.archive_url`, and `upstream.archive_sha256` in `sources/manifest.toml`.
2. **Verify Integrity**: Run `julia --startup-file=no --project=. sources/verify_sources.jl`.
3. **Audit Overlays**: Check if upstream modified `Common/CUDA/TIGRE_common.hpp` or `Common/CUDA/TIGRE_common.cpp`. If so, adjust `bundled/overlay/` to ensure exception translation and error buffers remain intact.
4. **Build and Validate**: Run `julia --startup-file=no --project=. build_tarballs.jl --verbose`.
5. **Execute Regression Suite**: Run `julia --startup-file=no --project=. test/integration_test.jl` against target GPU hardware.
6. **Submit Yggdrasil PR**: Copy recipe to `yggdrasil/T/Tigre/` and submit PR to Yggdrasil with updated version/tree-hash.

---

## 6. Rollback and Recovery Procedure

Preserving `deps/build.jl` in `Tigre.jl` ensures a resilient fallback for researchers and developers:
- **Instant Override via Environment Variable**:
  ```bash
  export LIBTIGRE_PATH="/path/to/custom/libtigre_julia.so"
  ```
- **Fallback to Local Compilation**:
  If JLL fails on an unsupported platform or custom CUDA environment, users can compile locally:
  ```julia
  using Pkg
  Pkg.build("Tigre") # compiles into deps/usr/lib/libtigre_julia.so
  ```
- **Diagnostics**:
  Running `doctor.jl` displays the active backend (`:jll` or `:source`), loaded library path, and GPU status.

