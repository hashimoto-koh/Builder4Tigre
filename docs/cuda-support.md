# CUDA サポート仕様とアーキテクチャ方針 (docs/cuda-support.md)

本ドキュメントでは、`libtigre_julia` のビルドにおいて対象とする CUDA Toolkit バージョン、GPU アーキテクチャ (Compute Capability / SASS)、PTX フォールバック、およびドライバ互換性方針を定義する。

---

## 1. サポート方針の基本原則

1. **ホスト NVIDIA Driver と CUDA Runtime の分離**:
   - `libtigre_julia` は `libcudart`（CUDA Runtime API）のみを動的リンクする。
   - `libcuda.so`（CUDA Driver API）へのリンクは行わず、実行時のホストシステム（NVIDIA Driver）から供給されるものを使用する。
   - 実行環境には、ビルド時の CUDA Toolkit バージョンを満たす NVIDIA Display / Compute Driver が導入されている必要がある。

2. **初期ターゲットと実機検証環境**:
   - **開発・実機検証対象**: NVIDIA GeForce RTX 3090 (`sm_86`)
   - **ホスト Driver**: 570.211.01 (CUDA 12.8 対応)
   - **初期ビルドターゲット**: CUDA 12.x 系列（Yggdrasil の `CUDA_SDK_jll` および `CUDA_Runtime_jll`）

---

## 2. 対象 GPU アーキテクチャとコード生成方針

`nvcc` で全てのアーキテクチャ向けにバイナリ（SASS）を生成すると、ライブラリファイルサイズが数ギガバイト規模に肥大化するリスクがある。
そのため、利用実績の多い主要アーキテクチャの SASS を含め、将来世代向けには最新の PTX を 1 つ含めて実行時 JIT コンパイルを可能とする構成をとる。

### 2.1 採用する Compute Capability (SASS)

| アーキテクチャ | Compute Capability | 代表 GPU 例 | ビルド方針 |
|---|---|---|---|
| Volta | `sm_70` | Titan V, V100 | SASS 生成 (`-gencode=arch=compute_70,code=sm_70`) |
| Turing | `sm_75` | RTX 2080, T4 | SASS 生成 (`-gencode=arch=compute_75,code=sm_75`) |
| Ampere | `sm_80` | A100 | SASS 生成 (`-gencode=arch=compute_80,code=sm_80`) |
| Ampere | `sm_86` | RTX 3090 (実機基準), RTX 3080 | SASS 生成 (`-gencode=arch=compute_86,code=sm_86`) |
| Ada Lovelace | `sm_89` | RTX 4090, RTX 4080, L40 | SASS 生成 (`-gencode=arch=compute_89,code=sm_89`) |
| Hopper | `sm_90` | H100 | SASS 生成 (`-gencode=arch=compute_90,code=sm_90`) |

### 2.2 PTX フォールバック
- 今後の新しい GPU アーキテクチャ（Blackwell 等）でもドライバが JIT コンパイルして動作できるよう、PTX 仮想アーキテクチャコードを 1 つ含める:
  `-gencode=arch=compute_86,code=compute_86` (またはビルド対象 CUDA バージョンに応じた最新の compute capability)

---

## 3. Yggdrasil `platforms/cuda.jl` との統合

Yggdrasil の CUDA プラットフォーム拡張機構に従い、以下のプラットフォームタグを付与してビルドする:

```julia
# 例: Linux x86_64 で CUDA 12 系列をターゲットとする場合
Platform("x86_64", "linux"; cuda="12.4")
```

- **Build 依存**: `CUDA_SDK_jll`（コンパイル時にヘッダーと nvcc ツールチェーンを供給）
- **Runtime 依存**: `CUDA_Runtime_jll`（実行時に `libcudart` を供給）

---

## 4. 実行時エラーハンドリング

GPU が利用できない環境、または対応する NVIDIA ドライバが存在しない環境で `libtigre_julia` がロードされた場合:
- `Libdl.dlopen` 自体は成功し、ライブラリの診断・エクスポートシンボルの参照が可能であること。
- `tigre_julia_get_gpu_count()` は `0` を安全に返すこと。
- 実際のカーネル呼び出し（`tigre_julia_ax` 等）が行われた場合は、CUDA runtime error を捕捉して `TIGRE_JULIA_STATUS_RUNTIME_ERROR` を返し、詳細メッセージ（例: `cudaErrorNoDevice` や `cudaErrorInsufficientDriver`）を `tigre_julia_last_error_message()` に設定すること（異常終了やクラッシュを防ぐ）。
