# 実機統合テスト手順書 (test/integration.md)

本ドキュメントは、実機 GPU（NVIDIA GeForce RTX 3090, `sm_86`）が搭載された環境において、`Builder4Tigre` でビルドした `libtigre_julia` を `Tigre.jl` と統合し、数値的整合性を検証するための手順書である。

---

## 1. 前提条件

- **ホスト環境**: Linux x86_64
- **NVIDIA Driver**: 550 以上（CUDA 12.x 対応ドライバ）
- **GPU**: RTX 3090 (`sm_86`)
- **Tigre.jl**: `/home/jov/git/prj/Tigre.jl/`

---

## 2. 統合検証手順

### ステップ 1: ライブラリのシンボルおよびスモークテスト
```bash
julia --startup-file=no --project=. test/symbols.jl
julia --startup-file=no --project=. test/smoke.jl
```

### ステップ 2: Tigre.jl からの直接参照検証
環境変数 `LIBTIGRE_PATH` または生成した JLL のアーティファクトパスを指定して `Tigre.jl` の診断 API を実行:

```bash
cd /home/jov/git/prj/Tigre.jl
julia --startup-file=no --project=. doctor.jl
```

- `available: true` であること
- `gpu_probe: ok` であり、RTX 3090 が検出されること

### ステップ 3: 投影・逆投影の数値回帰テスト
`Tigre.jl` の既存テストスイートを実行し、許容誤差（`atol`/`rtol`）内で完全に一致することを確認:

```bash
cd /home/jov/git/prj/Tigre.jl
julia --startup-file=no --project=. -e 'using Pkg; Pkg.test()'
```

主な検証項目:
1. `Ax`: Siddon 投影および Interpolated 投影（Cone-beam / Parallel-beam）
2. `Atb`: FDK 逆投影および Matched 逆投影
3. `TV`: TV 正則化 (`tigre_julia_min_tv`), AwTV (`tigre_julia_awmin_tv`)
4. `PICCS`: 事前画像付き圧縮センシング再構成
