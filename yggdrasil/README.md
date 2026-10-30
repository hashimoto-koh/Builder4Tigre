# Yggdrasil Recipe Staging (`yggdrasil/`)

This directory contains the exact directory structure and recipe ready for submission to [JuliaPackaging/Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil).

---

## Directory Structure

```text
yggdrasil/
└── T/
    └── Tigre/
        ├── build_tarballs.jl
        └── bundled/
            ├── overlay/
            │   ├── TIGRE_common.cpp
            │   └── TIGRE_common.hpp
            └── wrapper/
                ├── include/
                │   ├── tigre_julia_runtime.hpp
                │   └── tigre_julia_shim.h
                └── src/
                    ├── tigre_julia_runtime.cpp
                    └── tigre_julia_shim.cpp
```

---

## Instructions for Submitting to Yggdrasil

1. **Fork and Clone Yggdrasil**:
   ```bash
   git clone git@github.com:<your-username>/Yggdrasil.git
   cd Yggdrasil
   git checkout -b tigre-jll-initial
   ```

2. **Copy the Recipe**:
   ```bash
   # From your Builder4Tigre repository:
   cp -r /path/to/Builder4Tigre/yggdrasil/T/Tigre T/
   ```

3. **Verify Locally (Optional)**:
   ```bash
   # In the root of Yggdrasil:
   julia --project=. T/Tigre/build_tarballs.jl --verbose
   ```

4. **Commit and Push**:
   ```bash
   git add T/Tigre
   git commit -m "[Tigre] Initial recipe for libtigre_julia (v2.7.0)"
   git push origin tigre-jll-initial
   ```

5. **Open a Pull Request**:
   - Open a PR against `JuliaPackaging/Yggdrasil:master`.
   - Provide summary:
     - Project: CERN/TIGRE C/CUDA library wrapped for Julia (`Tigre.jl`).
     - Upstream commit: `81b6be2cc12ee630d36cba941e111ba14ba34c7c` (BSD-3-Clause).
     - Target: Linux x86_64, CUDA 12 series (`libcudart.so.12`).
     - Exported library: `libtigre_julia.so`.
