# Guild of Merchants

Godot 4.3で制作中の、PC向けファンタジー交易シミュレーションです。
契約と信用を頼りに各地を巡り、物流と市場の変化を読み解いて交易路を切り開く体験を中心にしています。

## 現在の開発状態

- メインシーン: `res://scenes/world.tscn`
- 基準解像度: 1920x1080
- MAP画面: MAP_BROWSE / MAP_CITY_FOCUS / MAP_TRAVEL_PREP の3状態を実装
- 市場: 売買、価格変動、週報の地域平均価格比較
- 今後の主要課題: プロローグ／TUT1、移動通知と入力制御の回帰確認
- ルートの最短・最安・最安全比較UI、バランス調整、Themeなどは後続課題

## 実行

Godot 4.3で`project.godot`を開き、メインシーンを実行します。

Windowsでのヘッドレス構文確認例:

```powershell
& 'C:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe' --headless --path . --editor --quit
```

## 主な構成

- `scripts/world.gd`: 世界状態、経済、日次処理、移動計算
- `ui/game_hud.gd`: UI母艦、CITY/MAPの状態遷移
- `scripts/map_layer.gd`: 地図描画、選択、経路、パン・ズーム
- `scenes/ui/map_mode_ui.tscn`: 本番用MAPレイアウト
- `data/`: 都市、商品、ルート、護衛などのCSV

## 開発・資料

- [資料索引](others/README.md)
- [開発運用（はじめに）](others/はじめに.txt)
- [現行引継](others/引継.txt)
- [ゲーム憲法](others/00_Guild_of_Merchants_憲法_v1.0_2026-03-16.txt)

標準作業フロー: **計画承認 → 作業ブランチで仕様・実装 → PRレビュー・Godot実画面確認 → 明示承認後にmainへマージ**。
過去の差分・ログは `others/archive/` に保存し、再適用しません。
