# Third-Party Notices and Attribution

This repository (`Builder4Tigre`) contains recipes, wrappers, and configuration to build `libtigre_julia` and package it as `Tigre_jll`. It incorporates and interfaces with third-party software as described below.

---

## 1. Upstream TIGRE

- **Project**: Tomographic Iterative GPU-based Reconstruction Toolbox (TIGRE)
- **Repository**: https://github.com/CERN/TIGRE
- **License**: BSD 3-Clause License
- **Copyright**: Copyright (c) 2015, University of Bath and CERN - European Organization for Nuclear Research. All rights reserved.

```text
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

---

## 2. Tigre.jl Wrapper and Shims

- **Project**: Tigre.jl
- **Repository**: https://github.com/hashimoto-koh/Tigre.jl
- **License**: BSD 3-Clause License
- **Copyright**: Copyright (c) 2024-2026, Koh Hashimoto and Tigre.jl contributors. All rights reserved.

The Julia C ABI shim (`tigre_julia_shim.cpp`, `tigre_julia_runtime.cpp`, headers, and common overlays) provides the bridge between Julia's `ccall` mechanism and TIGRE CUDA kernels without dependencies on MATLAB or Python runtimes.

---

## 3. NVIDIA CUDA Runtime / Toolkit

- **Components**: CUDA Runtime (`libcudart`), CUDA Toolkit build tools (`CUDA_SDK_jll`, `CUDA_Runtime_jll`)
- **License**: NVIDIA Software License Agreement (EULA)
- Redistribution of `libcudart` binaries within Julia artifacts is governed by NVIDIA's redistributable terms and JuliaPackaging's artifact distribution mechanisms. The host environment provides the NVIDIA display/compute driver (`libcuda.so`).
