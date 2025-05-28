# BUILD_SYSTEM_GUIDE.mdに従った設定

# ビルドプロファイル
when defined(release):
  switch("nimcache", "build/release/nimcache")
  switch("outdir", "build/release/bin")
  switch("opt", "size")
  switch("d", "release")
else:
  switch("nimcache", "build/debug/nimcache")
  switch("outdir", "build/debug/bin")
  switch("debugger", "native")
  switch("opt", "none")

# 共通のコンパイラオプション
switch("path", "src")
switch("d", "ssl")


# ワーニングの設定
switch("hints", "off")
hint("Processing", false)
hint("Conf", false)
warning("UnusedImport", true)
warning("BareExcept", true)

# テスト用の追加設定
when defined(test) or existsEnv("NIMBLE_TEST"):
  switch("path", "tests")
  switch("d", "test")

# ローカル開発用の依存関係
# TODO: パッケージが公開されたら削除
switch("path", "../nim-testkit/src")
switch("path", "../nim-configkit/src")