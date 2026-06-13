# zmk-config-roBa 開発知見

共通のビルド手順は [../CLAUDE.md](../CLAUDE.md) を参照。
本ファイルは roBa キーボード固有の情報を記録する。

---

## キーマップ変更時の必須作業

`config/roBa.keymap` の `default_layer` を変更するたびに、以下を必ず実施すること。

1. **README.md のキーマップ図を更新する**
   - `README.md` の「キーマップ (Default Layer)」セクションの ASCII 図を実態と合わせる
   - `keymap-drawer/roBa.yaml` も同様に更新する（SVG 再生成の元データ）

2. **cool642tb が同じ変更を受ける場合**
   - `zmk-config-cool642tb/config/cool642tb.keymap` も同様に変更する
   - `zmk-config-cool642tb/README.md` のキーマップ図も更新する

---

## ハードウェア構成

| 部位 | ボード | 役割 |
|------|--------|------|
| 右手 | XIAO BLE (nRF52840) | Central + トラックボール直結 |
| 左手 | XIAO BLE (nRF52840) | BLE Peripheral |

**トラックボール**: Pixart PMW3610（SPI接続、kumamuk-git カスタムドライバー使用）

| 信号 | nRF52840 ピン |
|------|--------------|
| SCK | P0.05 (xiao_d 5) |
| SDIO (MOSI/MISO) | P0.04 (xiao_d 4) |
| CS | P0.09 (gpio0 9) |
| MOTION (IRQ) | P0.02 (gpio0 2, active low + pull-up) |

---

## ファームウェア構成（build.yaml）

ZMK: `v0.3-branch` + kumamuk-git/zmk-pmw3610-driver（カスタムドライバー）
ボード名: `seeeduino_xiao_ble`

| シールド | 説明 |
|---------|------|
| roBa_R | 右手スタンドアロン（Central、USB、ZMK Studio対応） |
| roBa_R_coropit | 右手スタンドアロン（roBa_R の別設定版） |
| roBa_L | 左手ペリフェラル |

---

## トラックボール設定

カスタムドライバーが CPI・スクロール・スマートアルゴリズムを担当。
向き補正は input-processors の `zip_xy_transform` で適用。

**センサー向きの実測値（roBa R共通）**:
- 物理右 → センサー出力 `REL_Y`（負値）
- 物理上 → センサー出力 `REL_X`（正値）
- 補正: `INPUT_TRANSFORM_XY_SWAP | INPUT_TRANSFORM_Y_INVERT`

**レイヤー4 = MOUSE レイヤー**（mkp MB1/MB2/MB3 が配置）
`zip_temp_layer 4 500` でトラックボール操作時に 500ms 自動起動。

---

## ビルドターゲットと書き込み先

| uf2 ファイル | 書き込み先 |
|---|---|
| `roBa_L-seeeduino_xiao_ble-zmk.uf2` | 左手 XIAO BLE |
| `roBa_R-seeeduino_xiao_ble-zmk.uf2` | 右手（スタンドアロン） |
| `roBa_R_coropit-seeeduino_xiao_ble-zmk.uf2` | 右手（coropit設定） |
| `settings_reset-seeeduino_xiao_ble-zmk.uf2` | XIAO BLE ペアリングリセット |
