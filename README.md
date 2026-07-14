# Guild of Merchants

Godot 4.3で制作中の、PC向けファンタジー交易シミュレーションです。
契約と信用を頼りに各地を巡り、地理と物流の詰まりを読み解いて交易路を切り開く体験を中心にしています。

## 現在の開発状態

- メインシーン: res://scenes/world.tscn
- 基準解像度: 1920x1080
- MAP画面: 3状態の骨格実装と実画面確認まで完了
  - MAP_BROWSE: 地図閲覧
  - MAP_CITY_FOCUS: 都市確認
  - MAP_TRAVEL_PREP: 経路・費用・危険度・整備度・護衛を確認して出発
- 次の主対象: TUT1で「契約→購入→移動→納品→信用→解放」を一本につなぐ

数値調整、最短・最安・最安全の複数経路比較、Themeや装飾は後続フェーズです。

## 実行

Godot 4.3でproject.godotを開き、メインシーンを実行します。

Windowsでのheadless確認例:

```powershell
& 'C:\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64.exe' --headless --path . --editor --quit
```

## 主な構成

- scripts/world.gd: 世界状態、経済、日次処理、移動計算
- ui/game_hud.gd: UI母艦、CITY/MAPの状態遷移
- scripts/map_layer.gd: 地図描画、ノード選択、経路表示、パン・ズーム
- scenes/ui/map_mode_ui.tscn: 本番用MAPレイアウト
- scenes/dev/map_layout_preview.tscn.tscn: MAPレイアウト確認用シーン
- data/: 都市、商品、ルート、護衛などのCSV

## 参照資料

- others/はじめに.txt: 資料運用と参照優先順位
- others/引継.txt: 現在有効な方針、実装状態、次タスク
- Guild of Merchants 憲法 v1.0: 設計判断の最上位基準

詳細な作業履歴は引継へ追記せず、必要に応じてothers/archive/へ分離します。
