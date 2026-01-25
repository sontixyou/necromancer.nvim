# :Necromancer status コマンド設計

## 概要

プラグインごとの状態を確認するコマンド。各プラグインが「最新」「更新可能」「未インストール」「不整合」のどの状態かを表示する。

## 要件

- リモートの最新コミットも確認する（git fetch を実行）
- status 実行時に毎回 fetch（シンプルな実装）
- フローティングウィンドウで表示（既存の list コマンドと統一）

## アーキテクチャ

```
:Necromancer status
     ↓
1. 設定ファイル読み込み (.necromancer.json)
2. ロックファイル読み込み (.necromancer.lock)
3. 各プラグインに対して:
   a. インストール状態確認
   b. git fetch 実行
   c. 現在のコミットと設定を比較
   d. リモート HEAD との比較
4. ステータス一覧をフローティングウィンドウに表示
```

## ステータス種類

| ステータス | 条件 |
|-----------|------|
| `up-to-date` | 設定のコミット = 実際のコミット（リモートも同じ、または確認失敗時） |
| `outdated` | 設定のコミット ≠ 実際のコミット |
| `update available` | 設定のコミット = 実際のコミット、かつリモート HEAD ≠ 設定のコミット |
| `not installed` | プラグインディレクトリが存在しない |
| `corrupted` | ディレクトリはあるが .git がない等 |
| `fetch failed` | git fetch が失敗 |

### ステータス判定優先度

1. `not installed` - 最優先
2. `corrupted` - ディレクトリはあるが .git がない等
3. `outdated` - 設定と実際が不一致
4. `update available` - リモートに新しいコミット
5. `up-to-date` - 正常

## 実装詳細

### 変更ファイル

**lua/necromancer/commands.lua**:
```lua
---Get status of a single plugin
---@param plugin_def table Plugin definition from config
---@param install_dir string Installation directory
---@param lock table Lock file data
---@return table status {name, state, current_commit, config_commit, remote_commit}
local function get_plugin_status(plugin_def, install_dir, lock)

---Show status of all configured plugins
function M.cmd_status()
```

**lua/necromancer/core/git.lua**:
```lua
---Get remote HEAD commit (after fetch)
---@param repo_path string Path to repository
---@return string|nil commit Remote HEAD hash, or nil if failed
function M.get_remote_head(repo_path)
```

### 依存モジュール

- `config`: 設定ファイル読み込み
- `lockfile`: ロックファイル読み込み
- `git`: fetch, get_current_commit, get_remote_head
- `paths`: パス解決

## エラーハンドリング

| ケース | 対応 |
|--------|------|
| 設定ファイルなし | エラー通知して終了 |
| git fetch 失敗（ネットワークエラー等） | そのプラグインは `fetch failed` として表示、他は継続 |
| リモート HEAD 取得失敗 | `update available` 判定をスキップ |
| プラグインディレクトリ破損 | `corrupted` ステータスを表示 |

## 進捗表示

- fetch 実行中は `vim.notify` で進捗を表示
- 例: `Fetching updates... (3/10)`

## UI 仕様

### フローティングウィンドウ

- スタイル: `border = "rounded"`（既存の list と統一）
- タイトル: ` Necromancer Status `
- 幅: 70文字
- 高さ: プラグイン数 + ヘッダー行、最大20行

### 表示フォーマット

```
Plugin Status (fetched at 15:30:45):

  ✓ plenary.nvim         up-to-date       @ a3e3bc82
  ⬆ telescope.nvim       update available @ abc12345 → def67890
  ✗ nvim-treesitter      not installed
  ! nvim-cmp             outdated         @ 111aaaaa ≠ 222bbbbb
  ? some-plugin          fetch failed

Summary: 2 up-to-date, 1 update available, 1 outdated, 1 not installed
```

### アイコン

| アイコン | ステータス | 色 |
|---------|-----------|-----|
| `✓` | up-to-date | 緑 |
| `⬆` | update available | 青 |
| `!` | outdated | 黄 |
| `✗` | not installed | 赤 |
| `?` | fetch failed | 灰 |

### キーマップ

- `q` / `<Esc>`: ウィンドウを閉じる

## テスト計画

### tests/necromancer/commands_spec.lua

1. 設定ファイルがない場合 - エラーメッセージが表示されること
2. プラグインが未インストールの場合 - `not installed` ステータスが返ること
3. プラグインが最新の場合 - `up-to-date` が返ること
4. プラグインが outdated の場合 - `outdated` が返ること
5. get_plugin_status 関数の単体テスト

### tests/necromancer/core/git_spec.lua

6. get_remote_head の正常系 - origin/HEAD が取得できること
7. get_remote_head の異常系 - リモートがない場合に nil を返すこと
