# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Necromancer は純粋な Lua で実装された Neovim プラグインマネージャーです。Git コミットハッシュ（タグやブランチではなく）による決定論的なバージョン管理を特徴としています。

### 設計原則

- **Pure Lua**: 外部依存なし、Neovim (0.9+) と Git のみ必要
- **コミットハッシュバージョニング**: 40文字の SHA-1 ハッシュのみ使用
- **シンプルさ優先**: 直接的な実装、複雑な抽象化を避ける
- **同期的な実行**: `vim.fn.system` による Git 操作

## Development Commands

```bash
# 全テスト実行
make test

# Luaテストのみ実行
make test-lua

# 特定のテストファイルを実行
make test-file FILE=tests/necromancer/core/config_spec.lua

# テスト依存関係のインストール（plenary.nvim）
make test-deps

# クリーンアップ
make clean
```

## Architecture

### Data Flow

```
Config File (.necromancer.json)
  → Validation (validator.lua)
    → Dependency Resolution (dependencies.lua)
      → Installation (installer.lua)
        → Git Operations (git.lua)
          → Lock File Update (.necromancer.lock)
```

### Module Organization

**lua/necromancer/core/** - コアビジネスロジック
- `config.lua`: 設定ファイルの読み込み・検証、JSON パース
- `validator.lua`: 入力検証（コミットハッシュ、URL、プラグイン名）
- `dependencies.lua`: 依存関係解決（Kahn のアルゴリズムによるトポロジカルソート）
- `installer.lua`: プラグインインストール、検証、修復
- `git.lua`: Git 操作（clone, checkout, fetch）
- `lockfile.lua`: ロックファイル管理

**lua/necromancer/utils/** - ユーティリティ
- `paths.lua`: パス解決、チルダ展開
- `errors.lua`: カスタムエラー型（ValidationError, GitError, ConfigError）

**lua/necromancer/** - エントリポイント
- `init.lua`: `setup()` 関数、runtimepath 設定
- `commands.lua`: `:Necromancer` コマンド定義

### Key Patterns

**設定ファイルの検索順序**
1. カレントディレクトリ: `.necromancer.json`
2. グローバル: `~/.config/necromancer/config.json`

**プラグインインストール先**
- Unix/macOS: `~/.local/share/nvim/necromancer/plugins/<plugin-name>/`
- Windows: `%LOCALAPPDATA%\nvim\necromancer\plugins\<plugin-name>\`

**入力検証パターン**
```lua
-- コミットハッシュ: 40文字の16進数
hash:match("^[a-fA-F0-9]+$") and #hash == 40

-- GitHub URL
"^https://github%.com/[%w_%-]+/[%w%.%-_]+$"

-- プラグイン名: 1-100文字、英数字・ハイフン・アンダースコア・ドット
"^[%w_][%w%.%-_]*$"
```

**エラーハンドリング**
```lua
local errors = require("necromancer.utils.errors")

-- エラーの生成
error(errors.ValidationError("Invalid commit hash"))
error(errors.GitError("Clone failed"))
error(errors.ConfigError("Missing plugins array"))

-- エラーチェック
if errors.is_necromancer_error(err) then
  print(err.name .. ": " .. err.message)
end
```

**Git コマンド実行パターン**
```lua
-- vim.fn.system を使用した同期実行
local result = vim.fn.system({ "git", "clone", url, path })
if vim.v.shell_error ~= 0 then
  error(errors.GitError("Clone failed: " .. result))
end
```

### Plugin Dependencies

依存関係は Kahn のアルゴリズムによるトポロジカルソートで解決されます。

```json
{
  "plugins": [
    { "name": "plenary.nvim", "repo": "...", "commit": "..." },
    { "name": "telescope.nvim", "dependencies": ["plenary.nvim"], ... },
    { "name": "telescope-ui-select.nvim", "dependencies": ["telescope.nvim"], ... }
  ]
}
```

インストール順序: `plenary.nvim` → `telescope.nvim` → `telescope-ui-select.nvim`

**検証ルール**
- 全ての依存先は設定ファイル内に存在すること
- 循環依存は ValidationError で拒否
- 推移的依存関係は自動処理

## Testing

### Plenary.nvim によるテスト

- テストフレームワーク: `plenary.busted`
- テストファイル命名: `*_spec.lua`
- 最小設定: `tests/minimal_init.lua`

**テストの書き方**
```lua
local validator = require("necromancer.core.validator")

describe("validator", function()
  describe("is_valid_commit_hash", function()
    it("accepts valid 40-char hex hash", function()
      local hash = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
      assert.is_true(validator.is_valid_commit_hash(hash))
    end)

    it("rejects short hash", function()
      assert.is_false(validator.is_valid_commit_hash("a1b2c3d4"))
    end)
  end)
end)
```

### テストディレクトリ構造

```
tests/
├── minimal_init.lua          # テスト用最小Neovim設定
└── necromancer/
    ├── core/
    │   ├── config_spec.lua
    │   ├── validator_spec.lua
    │   ├── dependencies_spec.lua
    │   ├── git_spec.lua
    │   ├── installer_spec.lua
    │   └── lockfile_spec.lua
    ├── utils/
    │   └── paths_spec.lua
    └── commands_spec.lua
```

## Common Development Scenarios

### バリデーションルールの追加
1. `tests/necromancer/core/validator_spec.lua` にテスト追加
2. `lua/necromancer/core/validator.lua` に実装
3. 必要に応じて `config.lua` で使用

### 新しいコマンドの追加
1. `lua/necromancer/commands.lua` にコマンド登録
2. `tests/necromancer/commands_spec.lua` にテスト追加

### Git 操作の変更
1. 入力を必ず検証してから `vim.fn.system` に渡す
2. シェルメタ文字のチェック（`validator.has_shell_metachar`）
3. エラーは `errors.GitError` でラップ

## File References Format

コード参照時は `file_path:line_number` 形式を使用。

例: "依存関係解決は `lua/necromancer/core/dependencies.lua:12` で実装"
