# Builder4Tigre

`Builder4Tigre` は、Julia の断層撮影再構成パッケージ [Tigre.jl](https://github.com/hashimoto-koh/Tigre.jl) が使用する native C/CUDA バックエンド共有ライブラリ `libtigre_julia` を [BinaryBuilder.jl](https://github.com/JuliaPackaging/BinaryBuilder.jl) で構築し、最終的に JLL パッケージ `Tigre_jll` として配布するためのビルドレシピ・パッチ・検証資産管理リポジトリです。

---

## 目的 (Purpose)

従来 `Tigre.jl` では、パッケージ導入時に利用者のホスト環境で `nvcc` や CUDA Toolkit を用いたローカルビルド（`Pkg.build("Tigre")`）が必要でした。
本プロジェクトの目的は、`libtigre_julia` を BinaryBuilder でビルドし、公式コミュニティツリー [Yggdrasil](https://github.com/JuliaPackaging/Yggdrasil) を経由して `Tigre_jll` として事前ビルド済みバイナリを配布可能にすることです。これにより、ユーザーはローカルの `nvcc` 環境を整えることなく、GPU ドライバのみで即座に `Tigre.jl` を利用可能になります。

> [!NOTE]
> **名称の区別**:
> - `Builder4Tigre`: 本リポジトリ（ビルドレシピ、パッチ、検証コードの管理）
> - `Tigre_jll`: 生成される Julia バイナリラッパーパッケージ（Yggdrasil により自動生成・登録予定）
> - `Tigre.jl`: アルゴリズムや公開 API を提供する高水準 Julia パッケージ

---

## ディレクトリ構成 (Repository Layout)

```text
Builder4Tigre/
├── bundled/                 # ビルドに同梱する Julia 専用 C ABI shim, overlay, patches
│   ├── wrapper/             # C ABI shim 実装・ヘッダー
│   ├── overlay/             # Upstream Common/CUDA を置き換える overlay ファイル
│   └── patches/             # Upstream へのパッチ (現在 0 件)
├── docs/                    # 技術文書・設計書
│   ├── build-design.md      # ビルド設計仕様書・Source Manifest
│   ├── cuda-support.md      # CUDA バージョン・GPU アーキテクチャ対応方針
│   ├── abi-contract.md      # C ABI 契約・エクスポートシンボル定義
│   └── release-process.md   # リリースおよび Yggdrasil への移行手順
├── sources/                 # ソースマニフェストとハッシュ検証スクリプト
│   ├── manifest.toml        # 固定コミット・アーカイブ URL・SHA256
│   └── verify_sources.jl    # チェックサム検証用 Julia スクリプト
├── test/                    # 単体検証スクリプト
│   ├── smoke.jl             # 基本ロード・GPU 列挙 smoke test
│   ├── symbols.jl           # 必須 12 C ABI シンボルのエクスポート検証
│   ├── runtests.jl          # テストランナー
│   └── integration.md       # 実機 GPU による Tigre.jl 統合試験手順
├── build_tarballs.jl        # BinaryBuilder ビルドレシピ
├── LICENSE                  # BSD 3-Clause License
├── NOTICE.md                # 著作権・サードパーティ告知
└── PLAN.md                  # 開発計画・進捗表
```

---

## ソースの再現性検証 (Source Verification)

本リポジトリは、外部の予期せぬリビジョン変更に依存せず、常に完全固定されたハッシュからビルドを再現します。

```bash
julia --startup-file=no --project=. sources/verify_sources.jl
```

---

## 検証とテスト (Testing)

```bash
julia --startup-file=no --project=. test/runtests.jl
```

---

## ライセンス (License)

本プロジェクトのラッパーおよびレシピは [BSD 3-Clause License](LICENSE) の下で公開されています。
Upstream CERN/TIGRE の著作権および NVIDIA CUDA 関連の告知については [NOTICE.md](NOTICE.md) をご参照ください。
