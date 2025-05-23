# MCP-Jujutsu Project Structure

This document explains the directory structure of the MCP-Jujutsu project.

---

# MCP-Jujutsu プロジェクト構造

このドキュメントは、MCP-Jujutsuプロジェクトのディレクトリ構造を説明します。

## Directory Structure / ディレクトリ構造

```
mcp-jujutsu/
├── README.md              # Project overview and setup / プロジェクトの概要とセットアップ手順
├── mcp_jujutsu.nimble     # Nimble package definition / Nimbleパッケージ定義
├── nim.cfg               # Nim compiler settings / Nimコンパイラ設定
├── nimble.cfg            # Nimble package manager settings / Nimbleパッケージマネージャー設定
├── .gitignore            # Git ignore file / Git無視ファイル
│
├── build/                # Compiled binaries / コンパイル済みバイナリ
│   └── mcp_jujutsu       # Main executable / メイン実行ファイル
│
├── docs/                 # Documentation / ドキュメント
│   ├── DELEGATION_UPDATE.md  # Delegation pattern implementation / 委譲パターン実装の説明
│   └── PROJECT_STRUCTURE.md  # This file / このファイル
│
├── scripts/              # Utility scripts / ユーティリティスクリプト
│   └── start-server.sh   # Server startup script / サーバー起動スクリプト
│
├── src/                  # Source code / ソースコード
│   ├── mcp_jujutsu.nim   # Main entry point / メインエントリーポイント
│   ├── core/             # Common core components / 共通コアコンポーネント
│   ├── single_repo/      # Single repository features / 単一リポジトリ機能
│   ├── multi_repo/       # Multi-repository features / マルチリポジトリ機能
│   └── client/           # Client implementation / クライアント実装
│
├── tests/                # Test files / テストファイル
│   ├── core/             # Core tests / コアテスト
│   ├── single_repo/      # Single repository tests / 単一リポジトリテスト
│   ├── multi_repo/       # Multi-repository tests / マルチリポジトリテスト
│   └── client/           # Client tests / クライアントテスト
│
├── examples/             # Usage examples / 使用例
│   └── example.nim       # Sample code / サンプルコード
│
├── card/                 # MCP card definition / MCPカード定義
│   └── card.json         # Card configuration / カード設定
│
└── vendor/               # External dependencies / 外部依存関係（git submoduleなど）
```

## Directory Descriptions / 各ディレクトリの説明

### `/src/core/`
Contains common core functionality / 共通のコア機能を含むディレクトリ：
- `config/`: Configuration management / 設定管理
- `mcp/`: MCP protocol implementation / MCPプロトコル実装
- `repository/`: Jujutsu repository operations / Jujutsuリポジトリ操作

### `/src/single_repo/`
Single repository mode implementation / 単一リポジトリモードの実装：
- `analyzer/`: Semantic analysis / セマンティック分析
- `config/`: Single repository specific configuration / 単一リポジトリ固有の設定
- `mcp/`: MCP server implementation / MCPサーバー実装
- `tools/`: Commit division tools / コミット分割ツール

### `/src/multi_repo/`
Multi-repository mode implementation / マルチリポジトリモードの実装：
- `analyzer/`: Cross-repository analysis / クロスリポジトリ分析
- `config/`: Multi-repository specific configuration / マルチリポジトリ固有の設定
- `mcp/`: MCP server implementation / MCPサーバー実装
- `repository/`: Repository manager / リポジトリマネージャー
- `tools/`: Multi-repository tools / マルチリポジトリツール

### `/tests/`
Contains test files mirroring the production directory structure / テストファイルを含むディレクトリ。本番のディレクトリ構造を反映しています。

### `/build/`
Stores compiled binary files. Ignored by `.gitignore` / コンパイルされたバイナリファイルを格納。`.gitignore`で無視されます。

### `/docs/`
Project documentation including technical specifications, API references, and usage guides / プロジェクトのドキュメント。技術仕様、API参照、使用ガイドなど。

### `/scripts/`
Shell scripts for development and deployment / 開発やデプロイメントのためのシェルスクリプト。

## Build Instructions / ビルド方法

```bash
# Build the project / プロジェクトのビルド
nimble build

# Run tests / テストの実行
nimble test

# Start the server / サーバーの起動
nimble run

# Or / または
./scripts/start-server.sh
```

## File Placement Guidelines / 新しいファイルの配置

- Source code / ソースコード: Place in appropriate subdirectory under `/src/` based on functionality / 機能に応じて`/src/`の適切なサブディレクトリに配置
- Tests / テスト: Place in `/tests/` mirroring production structure / `/tests/`に本番のディレクトリ構造を反映して配置
- Documentation / ドキュメント: Place in `/docs/` / `/docs/`に配置
- Scripts / スクリプト: Place in `/scripts/` / `/scripts/`に配置
- Executables / 実行ファイル: Automatically generated in `/build/` during build / ビルド時に自動的に`/build/`に生成