# リリースプロセス仕様書 (docs/release-process.md)

本仕様書は、`libtigre_julia` のビルドレシピをコミュニティ公式リポジトリ [JuliaPackaging/Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil) に登録し、自動生成される `Tigre_jll` パッケージを [Tigre.jl](https://github.com/hashimoto-koh/Tigre.jl) へ導入するまでの正式なリリースフローを定義する。

---

## 1. 配布と登録の前提方針

- **Yggdrasil 経由の公式 JLL を本筋とする**:
  General registry maintainers は手動生成された独自 JLL パッケージの新規登録を受け付けない方針をとっています。そのため、本リポジトリ (`Builder4Tigre`) はレシピ・パッチの事前検証の場とし、正式なバイナリ生成および登録は Yggdrasil に Pull Request を提出して行います。
- **リポジトリ名の区分**:
  - `hashimoto-koh/Builder4Tigre`: 本開発・検証用リポジトリ
  - `JuliaPackaging/Yggdrasil/T/Tigre/`: Yggdrasil 上の公式レシピディレクトリ
  - `Tigre_jll`: Yggdrasil ビルドシステムにより自動作成・タグ打ち・登録される Julia パッケージ

---

## 2. リリースおよび登録の手順

### ステップ 1: `Builder4Tigre` でのローカル検証
1. `sources/manifest.toml` のリビジョンと SHA256 ハッシュが確定していること。
2. `sources/verify_sources.jl` が通過すること。
3. `build_tarballs.jl` を用いてローカルまたは BinaryBuilder sandbox で artifact tarball が正常にビルドできること。
4. 生成された `libtigre_julia.so` に対し、`test/symbols.jl` および `test/smoke.jl` が通過すること。
5. 実機 GPU (`sm_86`) 環境で `Tigre.jl` の数値回帰テスト（Ax / Atb / TV）が通過すること。

### ステップ 2: Yggdrasil への Pull Request 提出
1. `JuliaPackaging/Yggdrasil` を fork する。
2. `T/Tigre/` ディレクトリを作成し、以下を配置する:
   ```text
   T/Tigre/
   ├── build_tarballs.jl
   └── bundled/
       ├── overlay/
       └── wrapper/
   ```
3. Yggdrasil の CI（Linux / CUDA ビルド）を通過させ、レビュアーの承認を得てマージされる。
4. Yggdrasil により `Tigre_jll` が自動生成され、Julia General registry に登録される。

### ステップ 3: `Tigre.jl` への統合
1. `Tigre.jl` に専用ブランチ（例: `feature/tigre-jll`）を作成。
2. `Project.toml` の `[deps]` に `Tigre_jll` を追加。
3. `src/bindings.jl` を更新し、`Tigre_jll.libtigre_julia` を優先的に使用するよう切り替える。
4. 既存の `deps/build.jl`（ローカルビルド経路）は開発者向け fallback として温存する。
5. CI および実機 GPU で全テストを通過させた後、PR を作成してマージする。

---

## 3. バージョニング方針

- **Upstream TIGRE バージョン**: 例 `2.x.y`
- **JLL ビルド番号**: レシピやパッチのみの更新時は JLL の build number（例: `v2.x.y+0`, `v2.x.y+1`）をインクリメントする。
- **ABI 破壊的変更時**: C ABI または `TigreJuliaGeometry` の構造が変更される場合は、`Tigre.jl` の minor/major バージョン互換性ポリシーに従って慎重に引き上げる。
