# 設計・仕様資料（specs）

作成当時の仕様判断と設計方針を保存するディレクトリです。
**コードの実装状況はGitHubの対象ブランチと `../引継.txt` を優先**してください。
番号は従来の資料名と対応します。内容の削除・実装済み扱いはしていません。

01 全体仕様・縦スライス
02 契約・商館・NPC
03 取引・市場・委託・定期市
04 評判・信用・商人ランク
05 移動・ルート選択・コスト配分
06 会話UI・モーダル入力
07 イベントダイス
08 港都市・港湾物流
09 ギルド／商館倉庫
10 経済プラスα（実装計画）
11 MAP画面設計

各仕様の最新版を明示する場合は、ファイルを上書きする前に関連コード・引継との差分を確認してください。

- [Phase 4-A 到着日の再出発制限撤廃](gom_phase4a_same_day_departure_spec_2026-11-26.txt)：05・11の補足仕様／実装計画（Windows実機確認待ち）

- [Phase 4-B 平常時経済設計](gom_phase4b_economy_design_2026-11-27.txt)：全体MAP・商品・都市・市場規模の設計
- [Phase 4-C-01 経済CSV調整](gom_phase4c01_economy_csv_spec_2026-11-27.txt)：既存36品の調整。採用値は[設定比較表](gom_c01_parameters.txt)、全24都市は[理論収支表](gom_c01_balance.txt)。

- [Phase 4-C-01b-1 物流計測仕様](gom_phase4c01b1_economy_telemetry_spec_2026-11-27.txt)：NPC・水運・工房・市場の計測基盤（実装済み）

- [Phase 4-C-01b-2 委託輸送型NPC仕様](gom_phase4c01b2_commission_logistics_spec_2026-11-27.txt)：都市金庫による報酬・需給判断・空荷移動（実装済み）

- [Phase 4-C-01b-S 保存対象台帳](gom_phase4c01bs_save_state_inventory_2026-11-27.txt)／[セーブver.3仕様](gom_phase4c01bs_save_v3_spec_2026-11-27.txt)：マスター分離・旧版移行・安全な保存復元（未実装）
