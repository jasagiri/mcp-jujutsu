# MCP-Jujutsu TODO

This file outlines the incomplete tasks and future development plans for the MCP-Jujutsu project.

---

# MCP-Jujutsu TODO

このファイルは MCP-Jujutsu プロジェクトの未完了タスクと今後の開発計画を示します。

## High Priority - Core Functionality / 優先度高 - 基本機能の完成

### Core Features / コア機能

- [x] Fix tests: Address undefined function `strip` errors in `test_jujutsu.nim` / テストの修正: `test_jujutsu.nim` の未定義関数 `strip` エラーなど対応
- [x] Repository connection implementation: Complete Jujutsu API connection in `src/core/repository/jujutsu.nim` / リポジトリ接続の実装: `src/core/repository/jujutsu.nim` のJujutsu API接続部分を完成
- [x] Properly implement exception handling for `discard` statements / `discard` 文で放置されている例外処理を適切に実装
- [x] Full implementation of resource handlers: Currently only basic framework / リソースハンドラーの完全実装: 現在は基本的な枠組みのみ

### Single Repository Features / 単一リポジトリ機能

- [x] Improve semantic analysis engine: Implement more advanced code analysis / セマンティック分析エンジンの改良: より高度なコード解析機能の実装
- [x] Enhance commit division proposal algorithm / コミット分割提案のアルゴリズムを強化
- [x] Complete configuration file loading functionality / 設定ファイル読み込み機能の完全実装

### Multi-Repository Features / マルチリポジトリ機能

- [x] Complete repository manager: Add dependency handling and configuration persistence / リポジトリマネージャーの完全実装: 依存関係処理と設定保存機能を追加
- [x] Enhance cross-repository analysis: Dependency detection, semantic grouping, commit proposal generation / クロスリポジトリ分析の強化: 依存関係検出、セマンティックグループ化、コミット提案生成
- [x] Improve dependency detection mechanism: Pattern-based detection and confidence scoring / 依存関係検出メカニズムの改良: パターンベースの検出と信頼度スコアリング
- [x] End-to-end testing for multi-repo commit division: Analysis, proposal generation, MCP integration / マルチリポジトリコミット分割のエンドツーエンドテスト: 分析、提案生成、MCP統合のテスト

### Operational Features / 運用機能

- [x] Enhance error logging: Structured logging, context information, configurable log levels / エラーログ機能の強化: 構造化ログ、コンテキスト情報、設定可能なログレベル
- [ ] Performance optimization / パフォーマンス最適化
- [ ] CI/CD pipeline configuration / CI/CDパイプラインの設定

## Medium Priority - UX Improvements and Enhancements / 優先度中 - UX改善と機能強化

### User Interface / ユーザーインターフェース

- [ ] Improve command-line interface usability / コマンドラインインターフェースの使いやすさ向上
- [ ] Implement detailed progress display / 詳細な進捗表示の実装
- [ ] Interactive proposal modification feature / インタラクティブな提案修正機能
- [ ] Visual commit division display / 視覚的なコミット分割表示機能

### AI Integration / AI統合

- [ ] Customization options for AI analysis proposals / AI分析提案内容のカスタマイズオプション
- [ ] Batch processing and queue system implementation / バッチ処理機能とキューシステムの実装
- [ ] Prompt versioning and improvement system / プロンプトのバージョン管理と改善機能
- [ ] User feedback learning mechanism / ユーザーフィードバックの学習メカニズム

### Configuration and Customization / 設定とカスタマイズ

- [ ] Configuration validation and sanitization / 設定値の検証とサニタイズ機能
- [ ] Project-specific configuration profiles / プロジェクト固有の設定プロファイル
- [ ] Plugin mechanism implementation / プラグイン機構の実装

## Low Priority - Future Enhancements / 優先度低 - 将来の強化

### Integration with Other Systems / 他システムとの統合

- [ ] Add Git support (besides Jujutsu) / Gitサポートの追加（Jujutsu以外）
- [ ] GitHub/GitLab integration / GitHub/GitLabとの統合
- [ ] CI/CD system integration / CI/CDシステムとの連携
- [ ] IDE extensions / IDE拡張機能

### Enterprise Features / エンタープライズ機能

- [ ] Team collaboration support / チーム共同作業のサポート
- [ ] Enforce commit standards / コミット標準の強制適用
- [ ] Audit and logging / 監査とロギング
- [ ] Reports and analytics / レポートと分析
- [ ] Role-based access control / ロールベースのアクセス制御

## Technical Debt / 技術的負債

- [ ] Refactor base code: Some placeholder implementations exist / 基本コードのリファクタリング: 現在は一部にプレースホルダー実装あり
- [ ] Improve test coverage: Current tests are partially stubs / テストカバレッジの向上: 現在のテストは一部がスタブのみ
- [ ] Expand documentation: API reference, configuration options / ドキュメントの拡充: API参照、設定オプション等
- [ ] Create performance benchmarks / パフォーマンスのベンチマーク作成

## Issues for Next Release (v0.2.0) / 次のリリースに向けた課題（v0.2.0）

1. Fix and complete unit tests / 単体テストの修正と完了
2. Stabilize basic Jujutsu integration / 基本的なJujutsu統合の安定化
3. Complete implementation of core features / コア機能の完全実装
4. Enrich user documentation / ユーザードキュメントの充実
5. Improve command-line interface usability / コマンドラインインターフェースの使いやすさ向上

## Development Roadmap / 開発ロードマップ

### v0.1.x - Internal Release / 内部リリース

- [x] Basic MCP server functionality / MCP基本サーバー機能
- [x] Implementation with delegation pattern / 委譲パターンによる実装
- [x] Basic Jujutsu integration / 基本的なJujutsu統合
- [x] Basic semantic analysis / 基本的なセマンティック分析
- [x] Complete test suite / テストスイートの完了

### v0.2.0 - Alpha Release / アルファリリース

- [ ] Full-featured Jujutsu integration / フル機能のJujutsu統合
- [ ] Improved semantic analysis / 改良されたセマンティック分析
- [ ] Enhanced command-line tools / コマンドラインツールの強化
- [ ] Basic AI integration / 基本的なAI統合

### v0.3.0 - Beta Release / ベータリリース

- [x] Complete implementation of multi-repository analysis / マルチリポジトリ分析の完全実装
- [x] Comprehensive test suite implementation / 包括的なテストスイートの実装
- [ ] Advanced AI integration / 高度なAI統合
- [ ] Improvements based on user feedback / ユーザーフィードバックに基づく改良
- [ ] Performance optimization / パフォーマンス最適化

### v1.0.0 - Official Release / 正式リリース

- [ ] Stabilization of all major features / すべての主要機能の安定化
- [ ] Complete documentation / 完全なドキュメント
- [ ] Production environment track record / 本番環境での実績
- [ ] Enterprise-level support / エンタープライズレベルのサポート