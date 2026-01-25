# グローバル設定パス対応設計

## 概要

`:Necromancer` コマンドを任意のディレクトリから実行可能にする。現状ではカレントディレクトリに `.necromancer.json` が存在しないと動作しない。

## 背景

現在の `paths.resolve_config_path()` は以下の順序で設定ファイルを検索する：
1. カレントディレクトリの `.necromancer.json`
2. グローバル設定 `~/.config/necromancer/config.json`

`setup()` には `config_path` オプションがあるが、コマンド側で参照されていないため機能していない。

## 設計

### 1. モジュールレベル変数で設定を保持

`lua/necromancer/init.lua` に `_config` テーブルを追加：

```lua
M._config = {
  config_path = nil,  -- setup() で指定された設定ファイルパス
  install_dir = nil,  -- setup() で指定されたインストールディレクトリ
}
```

`setup()` で設定を保存：

```lua
function M.setup(opts)
  opts = opts or {}
  M._config.config_path = opts.config_path
  M._config.install_dir = opts.install_dir
  -- 以降は既存ロジック...
end
```

### 2. commands.lua からの参照

ファイル冒頭で `necromancer` モジュールを require：

```lua
local necromancer = require("necromancer")
```

各コマンドで保存された設定を参照：

```lua
-- config_path
local config_path = paths.resolve_config_path(necromancer._config.config_path)

-- install_dir
local install_dir = necromancer._config.install_dir or paths.get_default_install_dir()
```

### 3. 影響を受けるコマンド

**config_path を参照:**
- `cmd_install`
- `cmd_list`
- `cmd_status`
- `cmd_clean`
- `cmd_update`
- `complete`（補完関数）

**install_dir を参照:**
- `cmd_install`
- `cmd_status`
- `cmd_clean`
- `cmd_update`

**影響なし:**
- `cmd_init` - 常にカレントディレクトリに作成（意図的）
- `cmd_self_update` - necromancer.nvim 自身のパスを使用

## 使用例

```lua
require("necromancer").setup({
  config_path = "~/.config/nvim/.necromancer.json",
  -- install_dir は省略可能（デフォルト使用）
})
```

## 設計の根拠

### モジュールレベル変数を選択した理由

1. **責務の明確さ** - `paths.lua` はパスの解決・変換のみを担当し、状態を持たない
2. **Neovim プラグインの慣習** - 多くのプラグインが `M.config` パターンを採用
3. **テストしやすさ** - `paths.lua` が純粋関数のままでテストが容易
4. **依存関係のシンプルさ** - `init.lua` が設定の中心となる
