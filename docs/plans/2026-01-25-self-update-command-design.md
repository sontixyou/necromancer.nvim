# self-update コマンド設計

## 概要

necromancer.nvim 本体を最新版に更新する `:Necromancer self-update` コマンドを追加する。

## 仕様

### コマンド

```
:Necromancer self-update
```

### 動作フロー

1. `paths.get_necromancer_path()` で necromancer.nvim のインストールパスを取得
2. Git リポジトリかどうか確認（`.git` ディレクトリの存在）
3. `git fetch --all` でリモートを取得
4. 現在の HEAD とリモート HEAD を比較
5. 差分があれば `git pull --ff-only` で更新
6. 結果を通知
7. 更新があった場合は Neovim 再起動を促す

### 設計判断

- **更新対象**: necromancer.nvim 本体のみ（管理プラグインは別コマンド）
- **更新方式**: リモート HEAD に自動更新（`git pull --ff-only`）
- **反映方法**: Neovim 再起動を促すのみ（ホットリロードは行わない）
- **`--ff-only` を使用**: ローカル変更がある場合は安全に失敗させる

## エラーハンドリング

| ケース | メッセージ |
|--------|-----------|
| パス不明 | `Could not determine necromancer.nvim path` |
| Git リポジトリでない | `necromancer.nvim is not a git repository` |
| fetch 失敗 | `Failed to fetch updates: <error>` |
| pull 失敗 | `Failed to update: local changes detected. Please commit or stash them.` |
| 既に最新 | `necromancer.nvim is already up-to-date` |
| 更新成功 | `necromancer.nvim updated! Please restart Neovim to apply changes.` |

## 実装

### 変更ファイル

1. `lua/necromancer/core/git.lua`
   - `M.pull(repo_path)` 関数を追加

2. `lua/necromancer/commands.lua`
   - `M.cmd_self_update()` 関数を追加
   - `dispatch()` に `self-update` サブコマンドを登録
   - `get_subcommands()` に追加
   - 補完対応

### 新規関数

```lua
-- git.lua
function M.pull(repo_path)
  git_exec({ "pull", "--ff-only" }, repo_path)
end

-- commands.lua
function M.cmd_self_update()
  local necromancer_path = paths.get_necromancer_path()

  if not necromancer_path then
    vim.notify("Could not determine necromancer.nvim path", vim.log.levels.ERROR)
    return
  end

  -- Git リポジトリ確認
  if vim.fn.isdirectory(necromancer_path .. "/.git") ~= 1 then
    vim.notify("necromancer.nvim is not a git repository", vim.log.levels.ERROR)
    return
  end

  -- fetch
  local ok, err = pcall(git.fetch, necromancer_path)
  if not ok then
    vim.notify("Failed to fetch updates: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  -- 比較
  local current = git.get_current_commit(necromancer_path)
  local remote = git.get_remote_head(necromancer_path)

  if current == remote then
    vim.notify("necromancer.nvim is already up-to-date", vim.log.levels.INFO)
    return
  end

  -- pull
  ok, err = pcall(git.pull, necromancer_path)
  if not ok then
    vim.notify("Failed to update: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  vim.notify("necromancer.nvim updated! Please restart Neovim to apply changes.", vim.log.levels.INFO)
end
```

## テスト

### テストファイル

- `tests/necromancer/core/git_spec.lua` に `pull` のテストを追加

### テストケース

1. `git.pull()` - 正常系: fast-forward 可能な場合
2. `git.pull()` - 異常系: ローカル変更がある場合
3. `cmd_self_update()` - 統合テスト（必要に応じて）
