# Tigre.jl 統合検証およびパッチ仕様書 (docs/tigre-jl-integration.md)

本仕様書は、BinaryBuilder で構築した `Tigre_jll` を `Tigre.jl` に組み込み、ローカルビルドなしで即座に GPU 再構成を実行可能にするための統合設計および検証結果をまとめたものである。

---

## 1. 統合の基本方針

1. **破壊的変更の禁止**:
   - `Tigre.jl` の公開 API（`Ax`, `Atb`, 各種再構成関数、幾何定義、戻り値型・配列形状）は 100% 維持する。
   - 既存のローカルビルド経路（`deps/build.jl`）は削除せず、開発者向けフォールバックとして温存する。

2. **優先度チェーン**:
   `native_library_path()` の解決順序:
   1. 環境変数 `LIBTIGRE_PATH` / `TIGRE_NATIVE_PATH` による明示的オーバーライド
   2. `Tigre_jll.is_available()` が `true` の場合、JLL アーティファクトパス (`Tigre_jll.libtigre_julia_path`)
   3. ローカルビルド成果物 `deps/usr/lib/libtigre_julia.so`

3. **診断機能の更新**:
   - `library_status()` に `backend = :jll | :source` を追加。
   - `doctor.jl` は JLL 利用時に「JLL backend active (no local nvcc needed)」と明示。

---

## 2. 実機 GPU (RTX 3090, `sm_86`) による数値回帰テスト結果

`test/integration_test.jl` において、`Tigre.jl` の全アルゴリズムに対し、JLL からロードされた `libtigre_julia.so` を用いて厳密な数値回帰テストを実施した。

| テスト項目 | アルゴリズム種別 | 結果 | 許容誤差 | 判定 |
|---|---|---|---|---|
| 1. `Ax` | Cone-beam 順投影 (Siddon) | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 2. `Atb` | Cone-beam 逆投影 (Matched) | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 3. `FDK` | FDK 再構成 (Hann フィルタ, Wang パディング) | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 4. `SART` | SART 反復再構成 (1 iter) | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 5. `FISTA` | FISTA 再構成 (TV 正則化付き) | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 6. `LSMR` | LSMR 反復解法 (1 iter) | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 7. `Hybrid FLSQR TV` | ハイブリッド FLSQR + TV | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 8. `PICCS` | 事前画像拘束圧縮センシング | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 9. `Parallel FBP` | Parallel-beam FBP (Hann フィルタ) | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 10. `MLEM` | 統計的 MLEM 再構成 | 一致 (sum, norm, min, max, samples) | `atol=1e-5`, `rtol=1e-5` | ✅ PASS |
| 11. `PCSD` | POCS TV 再構成 | 一致 (sum, norm, min, max, samples) | `atol=2e-4`, `rtol=1e-5` | ✅ PASS |
| 12. `AwPCSD` | 適応重み付き POCS TV | 一致 (sum, norm, min, max, samples) | `atol=2e-4`, `rtol=1e-5` | ✅ PASS |

**合計: 120 / 120 テスト全項目合格 (12.4s)**

---

## 3. パッチの適用手順 (`Tigre.jl` 側)

`patches/tigre_jl_jll_integration.patch` を `Tigre.jl` のブランチに適用する手順:

```bash
cd /path/to/Tigre.jl
git checkout -b feature/tigre-jll
git apply /path/to/Builder4Tigre/patches/tigre_jl_jll_integration.patch
```
