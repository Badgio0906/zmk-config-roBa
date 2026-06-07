# zmk-config-roBa 開発知見

共通のビルド手順は [../CLAUDE.md](../CLAUDE.md) を参照。
本ファイルは roBa キーボード固有の情報を記録する。

---

## ハードウェア構成

| 部位 | ボード | 役割 |
|------|--------|------|
| 右手（スタンドアロン） | XIAO BLE (nRF52840) | Central + トラックボール直結 |
| 右手（ペリフェラル） | XIAO BLE (nRF52840) | BLE Peripheral + トラックボール |
| 左手 | XIAO BLE (nRF52840) | BLE Peripheral |
| ドングル | XIAO BLE nRF52840 + Prospector Adapter | USB Central |

**トラックボール**: Pixart PMW3610（SPI接続）

| 信号 | nRF52840 ピン |
|------|--------------|
| SCK | P0.05 (xiao_d 5) |
| SDIO (MOSI/MISO) | P0.04 (xiao_d 4) |
| CS | P0.09 (gpio0 9) |
| MOTION | P0.02 (gpio0 2, active low + pull-up) |

---

## ファームウェア構成（build.yaml）

| シールド | ボード | 説明 |
|---------|--------|------|
| roBa_R | xiao_ble//zmk | 右手スタンドアロン（Central、USB） |
| roBa_R_coropit | xiao_ble//zmk | 右手スタンドアロン（Central、別設定） |
| roBa_L | xiao_ble//zmk | 左手ペリフェラル |
| roBa_R_periph | xiao_ble//zmk | 右手ペリフェラル（dongle使用時） |
| roBa_dongle prospector_adapter | xiao_ble/nrf52840/zmk | USB ドングル（Central） |

---

## トラックボール input-processors 設定

トラックボールの方向はシールドごとに異なる。

| シールド | input-processors |
|---------|-----------------|
| roBa_R | `zip_temp_layer 4 500`, `zip_xy_transform INPUT_TRANSFORM_XY_SWAP` |
| roBa_R_coropit | `zip_temp_layer 4 500`, `zip_xy_transform INPUT_TRANSFORM_XY_SWAP` |
| roBa_dongle (periph側) | `zip_xy_transform X_INVERT` → periph trackball_split に適用（現在ビルド無効） |
| roBa_dongle (central側) | `zip_temp_layer 4 500` → dongle trackball_listener に適用（現在ビルド無効） |

**センサー向きの実測値（roBa R共通）**:
物理右 → PMW3610 REL_Y(正値) / 物理上 → PMW3610 REL_X(正値)
→ `XY_SWAP | Y_INVERT` (= 0x5) で正方向に補正

**参考: 元のkumamuk-git版との違い**:
kumamuk版は badjeff/zmk-pmw3610-driver（カスタムドライバ）を使用し、
`CONFIG_PMW3610_ORIENTATION_180=y` でドライバ内部に向き補正を実装。
本フォークは標準Zephyrドライバを使用するため `input-processors` で補正が必要。

**レイヤー4 = MOUSE レイヤー**（mkp MB1/MB2/MB3 が配置）

---

## 既知の問題と修正履歴

### 1. Kconfig 警告エラー（解決済み）

詳細: [../ZMK_Zephyr4x_ビルド対応知見.md](../ZMK_Zephyr4x_ビルド対応知見.md) の Section 1 参照。
対処: `CONFIG_WARN_DEPRECATED=n` を各 `.conf` に追加。

---

### 2. zmk,input-split の `reg` 必須化（解決済み）

詳細: [../ZMK_Zephyr4x_ビルド対応知見.md](../ZMK_Zephyr4x_ビルド対応知見.md) の Section 2 参照。
対処: `split_inputs` ラッパーノードを追加し `reg = <0>` を付与。

---

### 3. Prospector ドングル版でトラックボールが動かない（2026-06-07 調査・修正）

#### 症状
- `roBa_dongle prospector_adapter` + `roBa_R_periph` 構成でトラックボールが全く動かない
- キーボード入力は正常

#### 分析

**原因A（確実）: `roBa_dongle.overlay` の `trackball_listener` に `input-processors` がなかった**

動作している `roBa_R_coropit.overlay` との比較：

```
# roBa_R_coropit（動作する）
trackball_listener {
    device = <&trackball>;           ← 物理デバイス直結
    input-processors =
        <&zip_temp_layer 4 500>,     ← MOUSE レイヤー自動起動
        <&zip_xy_transform INPUT_TRANSFORM_X_INVERT>;
};

# roBa_dongle（修正前・動作しない）
trackball_listener {
    device = <&trackball_split>;     ← 仮想 split デバイス
    /* input-processors なし */
};
```

`zip_temp_layer` がないと、トラックボール動作時に MOUSE レイヤー（layer 4）が起動しない。
ZMK の `input_listener.c` の実装によっては、processors なしの場合にイベント処理チェーンが
正常に完結しないコードパスが存在する可能性がある。
また、必要なヘッダ（`input_transform.h`, `processors.dtsi`）も不足していた。

**原因B（副次的）: `roBa_R_periph.conf` に不要な `CONFIG_ZMK_STUDIO=y` があった**

BLE Peripheral かつ `CONFIG_ZMK_USB=n` の構成では ZMK Studio は使用不可。
Studio が GATT サービスを追加すると ATT ハンドルを消費し、
input-split GATT サービスの登録に影響する可能性がある。

#### 修正方針

1. `roBa_dongle.overlay`: 必要なヘッダを追加し、`zip_temp_layer` 定義と
   `input-processors` を `trackball_listener` に追加（coropit と同じ設定を採用）
2. `roBa_R_periph.conf`: `CONFIG_ZMK_STUDIO=y` / `CONFIG_ZMK_STUDIO_LOCKING=n` を削除

#### 修正内容（2026-06-07 実施）

**roBa_R_periph.overlay**（変更箇所）：
- `#include <dt-bindings/zmk/input_transform.h>` 追加
- `#include <input/processors.dtsi>` 追加
- `trackball_split` ノードに `input-processors = <&zip_xy_transform INPUT_TRANSFORM_X_INVERT>` 追加
  → 座標変換をペリフェラル側（BLE送信前）で適用する公式推奨パターンに準拠

**roBa_dongle.overlay**（変更箇所）：
- `#include <dt-bindings/zmk/input_transform.h>` 追加
- `#include <input/processors.dtsi>` 追加
- `zip_temp_layer` ノード定義を追加
- `trackball_listener` に `input-processors = <&zip_temp_layer 4 500>` 追加
  → トラックボール動作時に MOUSE レイヤー（4）を 500ms 自動起動

**roBa_R_periph.conf**（変更箇所）：
- `CONFIG_ZMK_STUDIO=y` 削除（BLE Peripheral + USB なし構成では不要・GATT リソース消費を削減）
- `CONFIG_ZMK_STUDIO_LOCKING=n` 削除

#### ビルド結果

```
end build[0] roBa_R_periph-xiao_ble__zmk-zmk
end build[0] roBa_dongle prospector_adapter-xiao_ble_nrf52840_zmk-zmk
```

全ターゲット成功（[0] = exit code 0）。

コンパイル済み DTS 出力の確認（期待値）:

- roBa_R_periph: `trackball_split@0 { device = <&trackball>; input-processors = <&zip_xy_transform 0x2>; }`
- roBa_dongle: `trackball_listener { device = <&trackball_split>; input-processors = <&zip_temp_layer 0x4 0x1f4>; }`

#### 適用手順

```bash
cd ~/github/zmk/zmk-config-roBa
docker compose up
```

書き込み先：
- `roBa_R_periph-xiao_ble__zmk-zmk.uf2` → 右手ペリフェラル（XIAO BLE）
- `roBa_dongle prospector_adapter-xiao_ble_nrf52840_zmk-zmk.uf2` → ドングル

#### 修正後も動作しない場合

1. **BLE ペアリングリセット**（最も可能性が高い）
   - 全デバイスに `settings_reset` uf2 を書き込む
   - 通常ファームウェアを再書き込み
   - ドングル→左手→右手の順でペアリング

2. **Docker イメージ再ビルド**（ZMK の最新修正を取得）
   ```bash
   docker compose build --no-cache
   docker compose up
   ```
   ZMK PR #2477（2024年12月）で input-split が本体統合された。
   それ以降のバグ修正が含まれていない可能性がある。

3. **input-processors の方向確認**
   トラックボールが動くが方向が逆の場合:
   - `INPUT_TRANSFORM_X_INVERT` → `INPUT_TRANSFORM_Y_INVERT` に変更
   - または `INPUT_TRANSFORM_XY_SWAP` を追加して調整

---

### 4. 通常版トラックボール 90° ずれ（2026-06-07 調査・修正）

#### 症状
- `roBa_R` / `roBa_R_coropit` でトラックボールを右に動かすとカーソルが上、上に動かすとカーソルが左に移動（90° ずれ）

#### 分析

PMW3610 センサーの物理実装向きの計測結果：
- 物理右 → センサー出力 `REL_Y`（負値）
- 物理上 → センサー出力 `REL_X`（正値）

旧設定 `INPUT_TRANSFORM_X_INVERT` のみの場合：
- `REL_Y` にはX_INVERTが作用しない → 右移動がカーソル上に変換される
- `REL_X` が負値に反転 → 上移動がカーソル左に変換される

旧設定 `(X_INVERT | XY_SWAP)` × 2 は同一変換を2回適用しており事実上 `X_INVERT + Y_INVERT` 相当。
これは右→下、上→左になっていた（症状は異なるが、いずれも誤り）。

#### 修正方針

`XY_SWAP + X_INVERT + Y_INVERT` (= 0x7) を1段で適用する：
- `REL_Y(−v)` → swap → `REL_X(−v)` → X_INVERT → `REL_X(+v)` → カーソル右 ✓
- `REL_X(+v)` → swap → `REL_Y(+v)` → Y_INVERT → `REL_Y(−v)` → カーソル上 ✓

#### 修正内容（2026-06-07 実施）

`roBa_R.overlay` / `roBa_R_coropit.overlay`：
```
# 修正前 (roBa_R_coropit)
<&zip_xy_transform INPUT_TRANSFORM_X_INVERT>

# 修正前 (roBa_R) ← 同一変換2回適用で不正確
<&zip_xy_transform (INPUT_TRANSFORM_X_INVERT | INPUT_TRANSFORM_XY_SWAP)>,
<&zip_xy_transform (INPUT_TRANSFORM_X_INVERT | INPUT_TRANSFORM_XY_SWAP)>

# 修正1回目 → 上下・左右が反転していたため再修正
<&zip_xy_transform (INPUT_TRANSFORM_XY_SWAP | INPUT_TRANSFORM_X_INVERT | INPUT_TRANSFORM_Y_INVERT)>

# 修正2回目 ← XY_SWAP のみ（右左 ✓ / 上下 ✗）
<&zip_xy_transform INPUT_TRANSFORM_XY_SWAP>

# 修正3回目（最終）← kumamuk-git原版参照により XY_SWAP | Y_INVERT が正解
<&zip_xy_transform (INPUT_TRANSFORM_XY_SWAP | INPUT_TRANSFORM_Y_INVERT)>
```

ビルド結果：全ターゲット成功（exit code 0）

---

## ビルドターゲットと書き込み先

| uf2 ファイル | 書き込み先 |
|---|---|
| `roBa_L-xiao_ble__zmk-zmk.uf2` | 左手 XIAO BLE |
| `roBa_R-xiao_ble__zmk-zmk.uf2` | 右手（スタンドアロン中央） |
| `roBa_R_coropit-xiao_ble__zmk-zmk.uf2` | 右手（coropit設定） |
| `roBa_R_periph-xiao_ble__zmk-zmk.uf2` | 右手ペリフェラル（ドングル使用時） |
| `roBa_dongle prospector_adapter-xiao_ble_nrf52840_zmk-zmk.uf2` | Prospector ドングル |
| `settings_reset-xiao_ble__zmk-zmk.uf2` | XIAO BLE ペアリングリセット |
| `settings_reset-xiao_ble_nrf52840_zmk-zmk.uf2` | XIAO BLE nRF52840 ペアリングリセット |
