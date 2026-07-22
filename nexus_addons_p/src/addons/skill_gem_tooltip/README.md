# Skill Gem Tooltip

> スキルジェムにツールチップを表示

| 項目 | 内容 |
| --- | --- |
| キー | `skill_gem_tooltip` |
| ソース | [skill_gem_tooltip.lua](skill_gem_tooltip.lua) |
| 設定画面 | なし（アドオン一覧の ON/OFF のみ） |
| 原作者 | ebisuke さん |

## 使い方

ON にして、**スキルジェムにマウスを乗せる**だけです。
通常のアイテムツールチップの隣に、**そのジェムが強化するスキルのツールチップ**が
並べて表示され、ジェム名からスキルを思い出す手間が無くなります。

追加ツールチップの先頭には `Skill Gem Tooltip` の見出しと、**そのスキルの職業名**が出ます。
職業名の末尾には系統を示す記号が付きます。

| 記号 | 系統 |
| --- | --- |
| `[S]` | ソードマン |
| `[W]` | ウィザード |
| `[A]` | アーチャー |
| `[C]` | クレリック |
| `[T]` | スカウト |

カーソルがスロットから外れると自動的に消えます。

## しくみ

`UPDATE_ITEM_TOOLTIP` をフックし、対象アイテムの `StringArg` が `SkillGem` のときだけ動きます。

1. アイテムの `SkillName` から `Skill` クラスを引く。
2. ゲームのスキルツールチップ（`ui.GetTooltipFrame("skill")`）を
   `_nexus_addons_pskill_gem_sub_tooltip` フレームへ丸ごと複製し、`UPDATE_SKILL_TOOLTIP` で中身を描く。
3. `SkillName` を `_` で分割して職業名と系統記号を取り出し、`Job` クラス一覧と突き合わせて
   表示名（性別込み）を得る。内部名と職業名がずれているもの
   （`FrostMage`→`Cryomancer`、`FireMage`→`Pyromancer`、`Warrior`→`Swordman`、
   `Lancer`→`Rancer`、`Templar`→`Templer`、`Outlaw`→`OutLaw`）は対応表で吸収する。
4. 表示位置は呼び出し元で変える。`inven`（インベントリ）と `char_belonging`（キャラ所持品）は
   元ツールチップの**右**、それ以外は**左**に寄せ、レイヤーは元ツールチップ +10。
5. 0.1 秒間隔でフォーカスを監視し、フォーカスが `slot` 以外になったらフレームを破棄する。

## 保存先

なし（ON/OFF は `../addons/_nexus_addons_p/<アカウントID>/settings.json` に入ります）。

## 注意

* 本家 Nexus Addons など、同名の旧初期化関数（`SKILLGEMTOOLTIP_ON_INIT`）を持つ
  アドオンが読み込まれている場合は、二重フックを避けるため初期化をスキップします。
* 職業名の対応表に無い内部名が今後追加された場合、その職業のジェムでは
  追加ツールチップが出ないことがあります（元のアイテムツールチップは通常どおり出ます）。
