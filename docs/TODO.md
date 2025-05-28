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
- [x] Performance optimization / パフォーマンス最適化 - LRU caching and profiling implemented
- [x] CI/CD pipeline configuration / CI/CDパイプライン設定 - GitHub Actions workflows added

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
- [x] Improve test coverage: Current tests are partially stubs / テストカバレッジの向上: 現在のテストは一部がスタブのみ
- [x] Expand documentation: API reference, configuration options / ドキュメントの拡充: API参照、設定オプション等 - API_REFERENCE.md added
- [ ] Create performance benchmarks / パフォーマンスのベンチマーク作成

## ✅ Test Coverage Status / テストカバレッジ状況 (2024-12)

- [x] **~95% test coverage achieved** / **~95%のテストカバレッジを達成**
  - [x] 15 source modules / 15個のソースモジュール
  - [x] 26 test files / 26個のテストファイル
  - [x] All core functionality tested / すべてのコア機能がテスト済み
  - [x] Integration tests for MCP protocol / MCPプロトコルの統合テスト
  - [x] Unit tests for all strategies / すべての戦略のユニットテスト

## Reporting System Integration / レポートシステム統合 (2024-12)

- [x] No changes needed for MCP-Jujutsu in reporting refactoring / レポーティングリファクタリングでmcp-jujutsuは変更不要
- [x] Focus remains on VCS operations and semantic analysis / VCS操作とセマンティック分析に専念
- [ ] Consider future integration with nim-testkit for testing workflows / 将来的にnim-testkitとのテスト ワークフロー統合を検討

## ✅ Recent Achievements / 最近の成果 (2025-05)

### Environment Compatibility Resolution / 環境互換性の解決

- [x] **Jujutsu version compatibility implemented** / **Jujutsuバージョン互換性を実装**
  - [x] Fixed revset syntax: `@~` → `@-` for v0.28.2+ / revset構文修正: v0.28.2+で`@~` → `@-`
  - [x] Removed deprecated `jj add` command (auto-tracking in v0.28+) / 非推奨の`jj add`コマンドを削除（v0.28+では自動追跡）
  - [x] Fixed `createCommit` function for proper working copy management / 作業コピー管理のため`createCommit`関数を修正
  - [x] All tests now pass with Jujutsu v0.28.2 / Jujutsu v0.28.2ですべてのテストが通過

- [x] **Environment-independent test fixes** / **環境非依存のテスト修正**
  - [x] Fixed `extractFileExtension` edge cases (hidden files, no extension, etc.) / `extractFileExtension`のエッジケース修正（隠しファイル、拡張子なしなど）
  - [x] Enhanced `detectChangeType` with conventional commit support / 従来のコミット形式をサポートする`detectChangeType`の強化
  - [x] Improved file type statistics handling / ファイルタイプ統計処理の改善
  - [x] Test failures reduced from 6 to 0 / テスト失敗数を6から0に削減

### Version Management Strategy / バージョン管理戦略

- [x] **Implemented version detection framework** / **バージョン検出フレームワークを実装**
  - Created `jujutsu_version.nim` with auto-detection / `jujutsu_version.nim`で自動検出機能を作成
  - Version-specific command adaptation / バージョン固有のコマンド適応
  - Capability detection (auto-tracking, revset syntax, etc.) / 機能検出（自動追跡、revset構文など）
  - Comprehensive documentation in `JUJUTSU_VERSION_COMPATIBILITY.md` / `JUJUTSU_VERSION_COMPATIBILITY.md`での包括的ドキュメント

- [x] **Supported Jujutsu versions** / **サポートするJujutsuバージョン**
  - v0.28.x+: Full support with auto-tracking / フルサポート（自動追跡あり）
  - v0.27.x: Full support with manual add / フルサポート（手動追加あり）
  - v0.26.x: Basic support / 基本サポート
  - Graceful fallback for unknown versions / 未知バージョンでの優雅なフォールバック

## Current Priority Tasks / 現在の優先タスク

### High Priority - Version Management / 優先度高 - バージョン管理

- [ ] **Complete version adaptation system** / **バージョン適応システムの完成**
  - [ ] Integrate version detection into main codebase / メインコードベースにバージョン検出を統合
  - [ ] Add version-specific command builders / バージョン固有のコマンドビルダーを追加
  - [ ] Test with multiple Jujutsu versions / 複数のJujutsuバージョンでテスト
  - [ ] Performance optimization for version caching / バージョンキャッシュのパフォーマンス最適化

- [ ] **Backward compatibility strategy** / **後方互換性戦略**
  - [ ] Support for Jujutsu v0.25.x and earlier / Jujutsu v0.25.x以前のサポート
  - [ ] Command fallback mechanisms / コマンドフォールバック機構
  - [ ] Feature detection and graceful degradation / 機能検出と優雅な劣化
  - [ ] Migration guide for version upgrades / バージョンアップグレード移行ガイド

### Medium Priority - Operational Improvements / 優先度中 - 運用改善

- [ ] **Enhanced error handling** / **エラーハンドリングの強化**
  - [ ] Better error messages for version mismatches / バージョン不一致時のより良いエラーメッセージ
  - [ ] Automatic retry mechanisms / 自動リトライ機構
  - [ ] Diagnostic information collection / 診断情報収集
  - [ ] User-friendly troubleshooting guides / ユーザーフレンドリーなトラブルシューティングガイド

- [ ] **Configuration management** / **設定管理**
  - [ ] Version override options / バージョンオーバーライドオプション
  - [ ] Environment-specific configurations / 環境固有の設定
  - [ ] Runtime configuration validation / ランタイム設定検証
  - [ ] Configuration migration tools / 設定移行ツール

## Version Management Best Practices / バージョン管理のベストプラクティス

### Implementation Guidelines / 実装ガイドライン

1. **Always use version-aware functions** / **常にバージョン対応関数を使用**
   ```nim
   # Good / 良い例
   let commands = await getJujutsuCommands()
   let cmd = buildInitCommand(commands)
   
   # Bad / 悪い例
   let cmd = "jj git init"  # Version-specific
   ```

2. **Check capabilities before using features** / **機能使用前に機能確認**
   ```nim
   let capabilities = getJujutsuCapabilities(version)
   if capabilities.hasAutoTracking:
     # Use auto-tracking workflow
   else:
     # Use manual add workflow
   ```

3. **Graceful fallback for unsupported operations** / **サポートされていない操作への優雅なフォールバック**
   ```nim
   try:
     await advancedJujutsuOperation()
   except UnsupportedVersionError:
     await basicJujutsuOperation()
   ```

### Testing Strategy / テスト戦略

- [ ] **Multi-version testing matrix** / **マルチバージョンテストマトリックス**
  - Docker containers with different Jujutsu versions / 異なるJujutsuバージョンのDockerコンテナ
  - Automated testing across version matrix / バージョンマトリックスでの自動テスト
  - Version-specific test cases / バージョン固有のテストケース
  - Compatibility regression testing / 互換性回帰テスト

- [ ] **Mock testing for unavailable versions** / **利用できないバージョンのモックテスト**
  - Command output simulation / コマンド出力シミュレーション
  - Error condition testing / エラー条件テスト
  - Performance testing with mocks / モックを使用したパフォーマンステスト

## Issues for Next Release (v0.2.0) / 次のリリースに向けた課題（v0.2.0）

1. **Complete version management system** / **バージョン管理システムの完成**
2. **Multi-version testing and validation** / **マルチバージョンテストと検証**
3. **Performance optimization for version detection** / **バージョン検出のパフォーマンス最適化**
4. **Comprehensive documentation and migration guides** / **包括的ドキュメントと移行ガイド**
5. **User experience improvements for version conflicts** / **バージョン競合時のユーザーエクスペリエンス改善**

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