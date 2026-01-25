# :Necromancer update コマンド設計

## 概要

プラグインを設定ファイルで指定されたブランチの「1週間前のコミット」に更新するコマンド。安定性を重視し、最新の不安定なコミットを避ける設計。

## コマンドインターフェース

```
:Necromancer update          # 全プラグインを更新
:Necromancer update [name]   # 特定プラグインのみ更新
```

### 処理フロー

1. 設定ファイル（`.necromancer.json`）を読み込み
2. 対象プラグインごとに：
   - `git fetch --all` でリモートから最新情報を取得
   - 対象ブランチの1週間前コミットを特定
   - 設定ファイルの `commit` フィールドを更新
   - 該当コミットに checkout
3. 成功したプラグインの情報で設定ファイルを上書き保存
4. lockfile も更新

### 出力例

```
Fetching telescope.nvim...
Updated telescope.nvim: abc1234 → def5678 (branch: main, 7 days ago)
Fetching plenary.nvim...
plenary.nvim is already up to date
Update complete: 1 updated, 1 skipped, 0 failed
```

## 設定ファイルのスキーマ拡張

### 新しいフィールド `branch`（オプション）

```json
{
  "plugins": [
    {
      "name": "telescope.nvim",
      "repo": "https://github.com/nvim-telescope/telescope.nvim",
      "commit": "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
      "branch": "main",
      "dependencies": ["plenary.nvim"]
    },
    {
      "name": "plenary.nvim",
      "repo": "https://github.com/nvim-lua/plenary.nvim",
      "commit": "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3"
    }
  ]
}
```

### ブランチ解決の優先順位

1. `branch` フィールドが指定されていればそれを使用
2. 未指定の場合、`git remote show origin` でデフォルトブランチを検出
3. 検出失敗時は `main` → `master` の順でフォールバック

### バリデーション追加（validator.lua）

- ブランチ名は英数字、ハイフン、アンダースコア、スラッシュ、ドットのみ許可
- パターン: `^[%w][%w%.%-_/]*$`

## Git 操作

### git.lua への新規関数追加

```lua
-- デフォルトブランチを検出
M.get_default_branch(repo_path)
-- git remote show origin | grep "HEAD branch" を解析
-- 失敗時は main → master のフォールバック

-- 指定ブランチの1週間前コミットを取得
M.get_commit_before_date(repo_path, branch, days_ago)
-- git log origin/{branch} --before="7 days ago" -1 --format="%H"
-- 1週間前にコミットが存在しない場合は最古のコミットを返す
```

### コマンド実行例

```bash
# デフォルトブランチ検出
git remote show origin | grep "HEAD branch"

# 1週間前のコミット取得
git log origin/main --before="7 days ago" -1 --format="%H"
```

### エッジケース処理

- リポジトリが1週間以内に作成された場合 → 最古のコミットを使用
- ブランチが存在しない場合 → GitError を発生
- fetch 前にこの処理を行うと古い情報になるため、必ず fetch 後に実行

## 設定ファイル更新処理

### config.lua への新規関数追加

```lua
-- 設定ファイルを更新（特定プラグインのcommitを変更）
M.update_plugin_commit(config_path, plugin_name, new_commit)

-- 複数プラグインのcommitを一括更新
M.update_plugins_commits(config_path, updates)
-- updates = { {name = "telescope.nvim", commit = "abc123..."}, ... }
```

### 更新フロー

1. 既存の設定ファイルを読み込み（JSON パース）
2. 対象プラグインの `commit` フィールドを更新
3. JSON として整形して書き戻し

### 整形ルール

- `vim.json.encode()` を使用
- 読みやすさのためインデント付き（可能であれば）

### 注意点

- 元のファイルのコメントや書式は保持されない（JSON 仕様上の制限）
- 更新前にバックアップは作成しない（git で管理されている前提）

## update コマンド実装（commands.lua）

### 新規関数 `cmd_update(args)`

```lua
function M.cmd_update(args)
  -- 1. 設定ファイル読み込み
  -- 2. 対象プラグイン決定（引数があれば単一、なければ全て）
  -- 3. 各プラグインに対して:
  --    a. fetch 実行
  --    b. ブランチ解決（指定 or デフォルト検出）
  --    c. 1週間前コミット取得
  --    d. 現在のコミットと比較（同じならスキップ）
  --    e. checkout 実行
  --    f. 成功リストに追加
  -- 4. 成功したプラグインで設定ファイル更新
  -- 5. lockfile 更新
  -- 6. 結果サマリー表示
end
```

### dispatch と補完への追加

- `get_subcommands()` に `"update"` 追加
- `complete()` で `update` の第2引数にプラグイン名補完
- `dispatch()` に `update` ケース追加

### 依存関係の考慮

- update 時も依存関係順でソート（dependencies.lua 使用）
- 依存先が更新失敗した場合でも、依存元は独立して処理（スキップしない）

## エラーハンドリング

| エラー | 対応 |
|--------|------|
| fetch 失敗（ネットワークエラー） | 該当プラグインをスキップ、警告表示 |
| ブランチが存在しない | 該当プラグインをスキップ、エラー表示 |
| 1週間前コミットが見つからない | 最古のコミットを使用、情報表示 |
| checkout 失敗 | 該当プラグインをスキップ、設定更新しない |
| 設定ファイル書き込み失敗 | エラー表示、処理中断 |

### 部分的失敗時の動作

- 成功したプラグインのみ設定ファイルに反映
- 失敗したプラグインは元の状態を維持

## テスト

### テストファイル

- `tests/necromancer/core/git_spec.lua` に `get_default_branch`、`get_commit_before_date` のテスト追加
- `tests/necromancer/commands_spec.lua` に `cmd_update` のテスト追加

### テスト観点

- 単一プラグイン更新
- 全プラグイン更新
- ブランチ指定あり/なし
- 既に最新の場合のスキップ
- 部分的失敗時の動作

## 実装タスク

1. `validator.lua`: ブランチ名バリデーション関数追加
2. `git.lua`: `get_default_branch`、`get_commit_before_date` 関数追加
3. `config.lua`: `update_plugin_commit`、`update_plugins_commits` 関数追加
4. `commands.lua`: `cmd_update` 関数追加、dispatch/補完対応
5. テスト追加
