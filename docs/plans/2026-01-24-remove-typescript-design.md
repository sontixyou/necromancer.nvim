# TypeScript/npm関連コードの削除

## 概要

プロジェクトをTypeScriptからLuaへ完全移行するため、TypeScript/npm関連のファイルをすべて削除する。

## 削除対象

### ディレクトリ
- `node_modules/` - npm依存関係
- `src/` - TypeScriptソースコード
- `dist/` - ビルド成果物
- `specs/` - TypeScript仕様書
- `implement-necromancer/` - 実装ドキュメント
- `examples/` - TypeScript用サンプル設定
- `tests/unit/` - TypeScriptユニットテスト
- `tests/integration/` - TypeScript統合テスト

### ファイル
- `package.json`
- `package-lock.json`
- `tsconfig.json`
- `vitest.config.ts`
- `CLAUDE.md`

## 残すもの

- `lua/` - Luaソースコード
- `plugin/` - Neovimプラグインエントリポイント
- `tests/necromancer/` - Luaテスト
- `tests/minimal_init.lua` - Luaテスト設定
- `doc/` - Vimヘルプドキュメント
- `Makefile` - Luaビルド/テスト用
- `README.md` - プロジェクト説明
- `CHANGELOG.md` - 変更履歴
- `LICENSE` - ライセンス
- `.github/` - GitHub設定
- `.gitignore` - Git除外設定

## 実行日

2026-01-24
