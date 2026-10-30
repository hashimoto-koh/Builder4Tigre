# libtigre_julia ビルド設計仕様書 (docs/build-design.md)

本仕様書は、[Tigre.jl](https://github.com/hashimoto-koh/Tigre.jl) が使用する native C/CUDA 共有ライブラリ `libtigre_julia` を BinaryBuilder.jl で再現可能に構築し、`Tigre_jll` として配布するためのビルド入力・出力・ABI 契約・プラットフォーム要件を定義する。

---

## 1. 参照元と固定リビジョン (Source Manifest)

### 1.1 Tigre.jl
- **リポジトリ**: `https://github.com/hashimoto-koh/Tigre.jl`
- **調査時 HEAD コミット**: `da939625f5934c181c1b68f8f03c9922b64f7f71`
  - コミット内容: `build(deps): bump upstream pinned commit to 81b6be2c and drop merged PICCS patch`

### 1.2 Upstream CERN/TIGRE
- **リポジトリ**: `https://github.com/CERN/TIGRE.git`
- **固定コミット (Ref)**: `81b6be2cc12ee630d36cba941e111ba14ba34c7c`
- **アーカイブ URL**: `https://github.com/CERN/TIGRE/archive/81b6be2cc12ee630d36cba941e111ba14ba34c7c.tar.gz`
- **アーカイブ SHA256**: `8e757c629982285a77d01e136f688ec3f659adb54bbfce91f48dc39f633fdc4a`

---

## 2. ソース構成と適用手順

### 2.1 Upstream ソース (`Common/CUDA`)
現行の Julia 連携に必要な 15 ソースファイル:
1. `projection.cpp`
2. `TIGRE_common.cpp` (※オーバーレイにより上書き)
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

### 2.2 オーバーレイ (Overlay)
Upstream の `Common/CUDA/` の同名ファイルを上書きするファイル:
| ファイルパス (配置元) | 対象ファイル | SHA256 |
|---|---|---|
| `deps/wrapper/overlay/TIGRE_common.hpp` | `Common/CUDA/TIGRE_common.hpp` | `9db1ef477613ff86b42036f03b2a88ca2992c1976ac1157152f8c16a04df8fb2` |
| `deps/wrapper/overlay/TIGRE_common.cpp` | `Common/CUDA/TIGRE_common.cpp` | `7cd1ff4217f8999c381acbf487508ff2ccb5884f79d66e9f1063cfb36ebbe546` |

- **目的**: C++ 内部での MATLAB/Python 例外送出処理（`mexErrMsgTxt` や Python C-API）を Julia 向けの error buffer 格納処理に差し替える。

### 2.3 Julia 専用 Shim / Runtime
Julia の `ccall` 境界と C ABI を提供するファイル群:
| ファイルパス | 役割 | SHA256 |
|---|---|---|
| `deps/wrapper/include/tigre_julia_shim.h` | 公開 C ABI ヘッダー（構造体、enum、関数宣言） | `85c79eebd88675bf98fdb0d18b0de6573205ec6cfb7d7839b6188eb68f733e89` |
| `deps/wrapper/include/tigre_julia_runtime.hpp` | 内部スレッドセーフエラー保持ランタイムヘッダー | `4509e84eb595e2aad3d8af96a809571b679b4ec7f4d8068fd20863dc59d85d58` |
| `deps/wrapper/src/tigre_julia_runtime.cpp` | エラーメッセージバッファ実装 | `d3f10a42746333a7bf81cd8161d21274f1b80ad66d5d2032aecd4fb5e0e5a15b` |
| `deps/wrapper/src/tigre_julia_shim.cpp` | C ABI shim 実装（`extern "C"` エクスポート） | `b662c927affce84b276f73f858ccbdc9f26ae583997a8463c0dd12dfd05d5068` |

### 2.4 パッチ (Patches)
- コミット `da939625f5934c181c1b68f8f03c9922b64f7f71` にて upstream `81b6be2c` に PICCS 修正が取り込まれたため、**現在適用すべきパッチは 0 件**。

---

## 3. コンパイラフラグとビルド仕様

### 3.1 コンパイルコマンド基準
```bash
nvcc --shared -O3 --std=c++14 \
     --expt-relaxed-constexpr \
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

### 3.2 リンカー・依存関係の分析
- **リンク対象**: `libcudart.so`
- **非リンク対象**: `libcuda.so`（NVIDIA driver がホスト環境で提供するため、JLL ビルド時はリンクしない）
- **C++ 例外境界**: C ABI 境界を越えて C++ 例外が送出されないよう、すべての shim 関数で `try ... catch` を行い、エラーコード (`TigreJuliaStatus`) を返す。

---

## 4. C ABI 契約と Struct Layout

### 4.1 幾何構造体 (`TigreJuliaGeometry` / `CGeometry`)
Julia 側の `struct CGeometry` と完全互換の 28 フィールドレイアウト:
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
    const float* offOrigX;     // Ptr{Float32} (angles 長配列)
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

### 4.2 エクスポートされる 12 個の C ABI 関数
| 関数名 | 引数概要 | 戻り値 |
|---|---|---|
| `tigre_julia_ax` | `volume, geo, angles, nangles, proj_type, gpu_ids, gpu_cnt, out` | `int` (ステータスコード) |
| `tigre_julia_atb` | `proj, geo, angles, nangles, backproj_type, gpu_ids, gpu_cnt, out` | `int` (ステータスコード) |
| `tigre_julia_min_tv` | `vol, nx, ny, nz, alpha, maxiter, gpu_ids, gpu_cnt, out` | `int` (ステータスコード) |
| `tigre_julia_awmin_tv` | `vol, nx, ny, nz, alpha, maxiter, delta, gpu_ids, gpu_cnt, out` | `int` (ステータスコード) |
| `tigre_julia_tvdenoise` | `vol, nx, ny, nz, lambda, spacing_xyz, maxiter, gpu_ids, gpu_cnt, out` | `int` (ステータスコード) |
| `tigre_julia_piccs_tv` | `vol, prior, nx, ny, nz, alpha, ratio, maxiter, gpu_ids, gpu_cnt, out` | `int` (ステータスコード) |
| `tigre_julia_get_gpu_count` | `void` | `int` (GPU 数) |
| `tigre_julia_get_gpu_name` | `device_id, char* name, size_t len` | `int` (ステータスコード) |
| `tigre_julia_clear_last_error`| `void` | `void` |
| `tigre_julia_last_error_message` | `void` | `const char*` |
| `tigre_julia_last_error_tag` | `void` | `const char*` |
| `tigre_julia_error_string` | `int status` | `const char*` |

---

## 5. CUDA / プラットフォーム要件

### 5.1 初期ターゲット
- **OS / ABI**: Linux x86_64 (`x86_64-linux-gnu`)
- **実機検証 GPU**: RTX 3090 (Compute capability `sm_86`)
- **CUDA バージョン**: CUDA 12.x 系列 (Yggdrasil `CUDA_SDK_jll` + `CUDA_Runtime_jll`)

### 5.2 Yggdrasil 連携方針
- Yggdrasil の `platforms/cuda.jl` を用いた platform augmentation:
  - `CUDA_SDK_jll` を `BuildDependency` として使用。
  - `CUDA_Runtime_jll` をランタイムの `Dependency` としてバインド。
- コード生成フラグ:
  - 主要ターゲットアーキテクチャの SASS (`sm_86` 等) および将来互換のための PTX (`compute_86` 等) を指定。

---

## 6. ライセンスと配布条件

- **TIGRE**: BSD 3-Clause License (Copyright 2015, University of Bath and CERN)
- **Tigre.jl / Wrapper**: BSD 3-Clause License (Copyright 2024-2026, Koh Hashimoto and Tigre.jl contributors)
- **NVIDIA CUDA Runtime**: NVIDIA Software License Agreement に基づき、再配布可能ライブラリ（`libcudart`）の再配布条件を順守。
- 生成される JLL パッケージには、各ライセンス原文および著作権表示を含む `LICENSE` / `NOTICE` を同梱する。
