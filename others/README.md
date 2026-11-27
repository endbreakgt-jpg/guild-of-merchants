# others — 資料案内

このフォルダは開発資料用です。**現行のコードと古い構想・作業記録を混同しない**ため、用途別に分類しています。
作業開始時は「はじめに」→「引継」→対象コード・関連仕様の順に確認してください。

## 現行の入口（others直下）
- [はじめに.txt](はじめに.txt)：GitHub/PR運用、承認・検証・資料整理ルール
- [引継.txt](引継.txt)：現在の方針、実装状態、次タスク、注意点
- [Guild of Merchants 憲法](00_Guild_of_Merchants_憲法_v1.0_2026-03-16.txt)：ゲーム設計上の最上位原則
- このREADME：資料の分類・参照先

## 用途別ディレクトリ
- [specs/](specs/README.md)：設計・仕様の基礎資料（01～11）。作成年月が古いものもあり、最新コードと一致するとは限りません。
- [reference/](reference/README.md)：地域・経済・世界観の検討資料、PDF、産地初期案。確定仕様ではありません。
- [archive/](archive/README.md)：完了済みパッチ、古い差分、検証ログ。履歴保存が目的で、再適用はしません。
- [tests/](tests/README.md)：今後の検証手順・結果（原則としてPRでも検証状況を報告）。

## 現位置に残した素材
- `MAPnew.png` / `MAPnew.png.import` はGodotの `res://` リソースになり得るため、
  文書整理を理由に移動していません。素材の配置は別途リソース参照を調べて決めます。

## ファイル名と更新
- 仕様書は `others/specs/` 内に配置。後続の改訂は元の版と区別します。
- 関数差分のTXTは標準成果物ではありません。直接GitHubブランチを更新しPRでレビューします。
- 完了済みの独立したパッチ・試験ログは `others/archive/` へ移動し、古い運用説明を書き換えません。
- `引継.txt` は履歴を追記し続けず、現在有効な要点に上書き・圧縮します。

## 直近の経済調整資料
- [Phase 4-C-01b-1 物流計測仕様](specs/gom_phase4c01b1_economy_telemetry_spec_2026-11-27.txt)／[検証票](tests/gom_phase4c01b1_economy_telemetry_test_2026-11-27.txt)：実装・120日計測済み。Windows動作確認完了（ユーザー報告、個別項目未記録）。

- [Phase 4-C-01b-2 委託輸送仕様](specs/gom_phase4c01b2_commission_logistics_spec_2026-11-27.txt)／[検証票](tests/gom_phase4c01b2_commission_logistics_test_2026-11-27.txt)：実装・4条件検証済み。[経済比較結果](tests/gom_c01b2_logistics_results.txt)。
