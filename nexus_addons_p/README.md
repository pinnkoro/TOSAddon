# Nexus Addons P

Tree of Savior 用アドオン **Nexus Addons P** の説明。

norisan さんの [Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) を元にした派生版です。
本家 v1.1.6 以降に加えた不具合修正・新レイド対応をまとめ、**別アドオンとして独立配布**します。
アドオン名・保存フォルダ・グローバル関数名はすべて `_nexus_addons_p` 系にリネームしてあり、
バージョンは本家と独立して採番します。

40種類以上のアドオンの詰合せです。**各アドオンの詳しい使い方は、下の一覧から個別の README** を参照してください
（ゲーム内のヘルプ（`?` ボタン）にも要約があります）。

インストール方法はリポジトリ全体の [README](../README.md) を参照してください。

---

## アドオン一覧

各行の名前をクリックすると、そのアドオンの使い方・設定項目・保存先をまとめた README が開きます。

### 倉庫・アイテム管理

| アドオン | 概要 |
| --- | --- |
| [Another Warehouse](src/addons/another_warehouse/README.md) | チーム倉庫を見やすい一覧に差し替え、自動搬出入・自動入出金・セット取り出しを追加 |
| [Character Change Helper](src/addons/cc_helper/README.md) | ボルタエンブレム・カード・髪飾り・エーテルジェムなどをボタン 1 つで倉庫と出し入れして着脱（3 セット） |
| [Characters Item Serch](src/addons/characters_item_serch/README.md) | 全キャラのインベントリ・装備・倉庫を横断してアイテムを検索 |
| [Bulk Sales](src/addons/bulk_sales/README.md) | 雑貨屋で同じアイテムをまとめて一括売却 |
| [No Check](src/addons/no_check/README.md) | 各種確認ダイアログを省略。アイテム連続使用フレームとゴミ箱フレームを追加 |
| [Market Voucher](src/addons/market_voucher/README.md) | マーケットの売買履歴を記録して「売上伝票」として表示 |

### 装備・強化

| アドオン | 概要 |
| --- | --- |
| [Goddess Icor Manager](src/addons/goddess_icor_manager/README.md) | 刻印ページ × 8 部位のイコルを一覧表示し、セット単位で付け替え |
| [Continue Reinforce](src/addons/continue_reinforce/README.md) | ゴッデス装備を成功するまで連続強化（回数制限・補助剤の自動選択つき） |
| [Aethergem Manager](src/addons/aethergem_manager/README.md) | エーテルジェム 4 個の付け替えを自動化（6 セット） |
| [Monster Card Changer](src/addons/monster_card_changer/README.md) | モンスターカードのプリセットを 10 個に拡張し、倉庫との出し入れも自動化 |
| [Ancient Auto Set](src/addons/ancient_auto_set/README.md) | アシスターセットをキャラ毎に自動で付け替え（10 プリセット） |
| [Relic Change](src/addons/relic_change/README.md) | レリックのシアンジェム付け替えをボタン 1 つで |
| [Vakarine Equip](src/addons/vakarine_equip/README.md) | ヴァカリネの恩恵の判定をやり直すため、指定部位を着け直す |
| [Cupole Manager](src/addons/cupole_manager/README.md) | クポル未登録キャラでも街に入ると自動で 3 体呼び出す |
| [Auto Repair](src/addons/auto_repair/README.md) | 耐久が減ると緊急修理キットで自動修理。女神の証商店から自動補充 |
| [Job Change Helper](src/addons/job_change_helper/README.md) | 転職前の装備全解除と、脱いだ装備の着け直し |

### レイド・コンテンツ

| アドオン | 概要 |
| --- | --- |
| [Indun Panel](src/addons/indun_panel/README.md) | レイド・チャレンジ等の入場を 1 枚のパネルに集約（表示セット 3 つ） |
| [Indun List Viewer](src/addons/indun_list_viewer/README.md) | 全キャラのレイド入場回数・掃討回数を一覧表示。掃討バフの期限も警告 |
| [Quickslot Operate](src/addons/quickslot_operate/README.md) | 女神ポーションをレイドの種族に合わせて自動で差し替え。スロット保存／読込 |
| [Battle Ritual](src/addons/battle_ritual/README.md) | レイド入場時に自己バフを優先度順で自動使用（ソロ限定） |
| [Archeology Helper](src/addons/archeology_helper/README.md) | アーキオロジーで調べた位置をミニマップに記録。スタミナ錠の自動使用も |
| [Dungeon RP Charger](src/addons/dungeon_rp_charger/README.md) | 未知の聖域 3F でレリックポイントを自動補充 |
| [Acquire Relic Reward](src/addons/acquire_relic_reward/README.md) | 主要都市でレリッククエストの報酬を自動受領 |
| [Guild Event Warp](src/addons/guild_event_warp/README.md) | 画面右上のボタンからギルドイベントのボスマップへワープ |
| [Silent Velnice Ranking](src/addons/silent_velnice_ranking/README.md) | ヴェルニケで勝手に開くランキングを抑止（TAB で表示） |

### キャラクター・移動

| アドオン | 概要 |
| --- | --- |
| [Instant CC](src/addons/instant_cc/README.md) | バラック画面を経由せずキャラクターチェンジ |
| [Other Character Skill List](src/addons/other_character_skill_list/README.md) | 全キャラの錬成スキル・強化値・GearScore を一覧表示 |
| [Lets Go Home](src/addons/lets_go_home/README.md) | 登録したホームタウンのホームチャンネルへワープ |
| [Auto Map Change](src/addons/auto_map_change/README.md) | 高レベルマップへ入るときの確認ダイアログを自動で通す |
| [Auto Pet Summon](src/addons/auto_pet_summon/README.md) | キャラ毎に最後に連れていたペットを街で自動召喚 |
| [Save Quest](src/addons/save_quest/README.md) | ワープ用クエストの NPC を消して誤完了を防止。ショートカットパネルつき |

### 画面表示・情報

| アドオン | 概要 |
| --- | --- |
| [Always Status](src/addons/always_status/README.md) | 選んだステータスを常時表示（10 セット・色と表示名をカスタマイズ可） |
| [Muteki](src/addons/muteki/README.md) | 切らしたくないバフだけを大きなゲージ／アイコンで表示 |
| [My Buffs Control](src/addons/my_buffs_control/README.md) | バフ欄を移動可能にして、選んだバフを非表示にする |
| [Separate Buff Custom](src/addons/separate_buff_custom/README.md) | セパレートバフフレームに好きなバフを追加。スタック数と追従表示 |
| [Debuff Notice](src/addons/debuff_notice/README.md) | 自分がボスへ与えたデバフを大きく表示 |
| [Sub Map](src/addons/sub_map/README.md) | メンバー・ボス・宝箱・未探索エリアを重ねた小さなマップを常時表示 |
| [Boss Direction](src/addons/boss_direction/README.md) | ボスが向いている方向を足元の矢印で表示 |
| [Boss Gauge](src/addons/boss_gauge/README.md) | ボスゲージにスタン値とシールド値を追加 |
| [Party Marker](src/addons/party_marker/README.md) | パーティーメンバーの頭上にアイコンを表示 |
| [Pick Item Tracker](src/addons/pick_item_tracker/README.md) | そのマップで拾ったアイテムと滞在時間を表示 |
| [Monster Kill Count](src/addons/monster_kill_count/README.md) | マップ別に討伐数・滞在時間・ドロップを記録して集計 |
| [Status Point Check](src/addons/status_point_check/README.md) | ステータスポイントがもらえるクエストの達成状況を一覧 |
| [Skill Gem Tooltip](src/addons/skill_gem_tooltip/README.md) | スキルジェムに対象スキルのツールチップを併記 |
| [Revival Timer](src/addons/revival_timer/README.md) | 繰り返しカウントダウンするタイマー（PT チャット通知つき） |
| [Tavern of Soul](src/addons/tavern_of_soul/README.md) | アイテム・バフ・スキル・モンスターの ID を逆引きする簡易検索 |

### その他

| アドオン | 概要 |
| --- | --- |
| [Sub Slotset](src/addons/sub_slotset/README.md) | 追加のクイックスロットを好きな大きさ・位置に何枚でも作る |
| [Easy Buff](src/addons/easy_buff/README.md) | メシ屋・バフ屋・修理屋での操作を自動化 |
| [Ancient Monster Bookshelf](src/addons/ancient_monster_bookshelf/README.md) | **未完成のため無効**（アシスターカードの一括合成） |

---

## ⚠️ 本家 Nexus Addons とは同時に使えません

Nexus Addons P は本家をリネームした派生版のため、**両方を同時にインストールすると競合します**。
そのため次の動作が入っています。

* **本家を検出したら、Nexus Addons P は全機能を停止します。**
  チャットに赤字で「本家を削除してください」と表示されるので、`data` フォルダから
  本家の `_nexus_addons-⛄-*.ipf` を削除して、クライアントを**再起動**してください。
  （この間、本家側は今までどおり動作します）
* **設定は自動で引き継がれます。**
  Nexus Addons P 側の設定がまだ無い状態で本家の設定が残っていれば、
  `addons/_nexus_addons/<アカウントID>/` の中身を `addons/_nexus_addons_p/<アカウントID>/` へ
  丸ごとコピーします（各アドオンの設定・Another Warehouse・討伐カウントなどを含む）。
  引き継ぎは**初回1回だけ**なので、本家を削除する前に一度ログインしておけば、
  そのままの設定で移行できます。

### 乗り換え手順

1. アドオンマネージャーから **Nexus Addons P** をインストールする（本家はまだ消さない）
2. ゲームを起動してログインする → 設定が引き継がれ、「本家を削除してください」と表示される
3. `data` フォルダから本家の `_nexus_addons-⛄-*.ipf` を削除する
4. クライアントを再起動する → 引き継いだ設定のまま Nexus Addons P が動作する

---

## 更新履歴

<details>
<summary>更新履歴 (Nexus Addons P)</summary>

* **v1.0.3**
  * **Characters Item Serch: OFF にしてあるのに、倉庫やチーム倉庫を閉じるたびに
    `[CIS] ...保存を中止しました` のメッセージが出ていたのを修正。**
    OFF のときは倉庫・インベントリの記録自体を行わないようにした
    （記録は ON の間だけ更新されるので、OFF の間に動かしたアイテムは ON に戻して
    倉庫を開き直すと反映される）。
  * **Characters Item Serch: チーム倉庫が検索に出なくなっていたのを修正。**
    情報を取得できないアイテムが 1 件でもあると倉庫まるごと記録を中止する動作だったため、
    その 1 件の巻き添えで全体が記録されていなかった（実機ではチーム倉庫 298 件のうち 1 件）。
    取得できなかったアイテムはアイテムの種類の名前で記録するようにして、
    残りを巻き添えにしないようにした。個人倉庫も同じ扱いにしている。
  * Indun List Viewer / Other Character Skill List / Bulk Sales: ウィンドウを閉じる ✕ ボタンを
    左上から**右上**へ移動（他のウィンドウと同じ位置に揃えた）。
  * **ESC で開いているウィンドウが一度に全部消えていたのを、一番手前の 1 枚だけ閉じるように変更。**
    対象は Indun List Viewer / Other Character Skill List / Goddess Icor Manager。
    これらを開いている間は ESC をアドオン側で受け取るので、**ウィンドウを閉じるときに
    チャットが消えたりシステムメニューが開いたりしなくなる**（全部閉じれば ESC はゲームへ戻る）。
    Other Character Skill List のキャラ詳細は本体より手前扱いで、ESC では先に詳細だけが閉じる
    （本体を ✕ で閉じたときは今までどおり一緒に閉じる。このとき詳細が閉じずエラーになっていたのも修正）。
    ※ Indun Panel は常時表示のため対象外（ESC で畳む従来の挙動のまま）だが、
    手前に上記のウィンドウが開いているときは畳まれなくなった。
  * 上記 ESC まわりの細かい不具合を追加で修正:
    * Goddess Icor Manager を ESC で閉じるとき、状況によって閉じ切れずウィンドウが
      残ることがあったのを修正（自分のウィンドウを先に閉じるようにした）。
    * ESC を素早く 2 回押しても 2 枚目が閉じず空振りすることがあったのを修正
      （手前を閉じてすぐ下を閉じる連打が効くようにした）。
    * ウィンドウを 1 枚閉じた直後のごく短い間、Indun Panel を ESC で開閉できなく
      なっていたのを修正。
  * アドオン一覧に「全て OFF」「バックアップ」「復元」のボタンを追加。
    「全て OFF」は登録アドオンをまとめて無効にする（確認あり）。
    「バックアップ」は現在の設定（`../addons/_nexus_addons_p/<AID>/` 配下すべて）を
    `../addons/_nexus_addons_p/backup/<AID>/` へ退避し、「復元」でそこから書き戻す。
    バックアップは 1 つだけ保持し、上書き前に取得日時を確認する（日時はボタンの
    ツールチップにも出る）。復元は上書きで、退避後に増えたファイルは消さない。
    復元後は反映しきらない設定があるため、ゲームの再起動を案内する。

* **v1.0.2**
  * Monster Kill Count: **「Map Reset」が今いるマップでは効かなかった不具合を修正。**
    記録ファイルは消えても集計がメモリに残っており、しばらくすると元の数値が書き戻っていた。
    別マップをリセットしたときに、消したはずのマップが「マップ情報」の一覧に残る問題も修正。
  * Monster Kill Count: 通ったマップが増えるほど「マップ情報」を開くのが重くなる問題を改善
    （一覧を出すたびに全マップの記録ファイルを読み直していたのをやめ、記録が空のマップは
    一覧の対象から外すようにした）。記録のあるマップが一覧から消えることはない。
  * Characters Item Serch: アイテム情報を取得できず保存を見送ったときに、その旨を
    チャットに表示するようにした。これまでは何も出ないまま検索結果が前回のままになるため、
    倉庫の中身と食い違っていても気付けなかった。
  * 詳細ログ: `verbose_log.txt` を開けなかったとき、次回以降が追記扱いになり
    前回起動分のログに書き足されることがあったのを修正。
    「中身は常に今回の起動分だけ」を保つ（不具合報告にそのまま添付できるようにするため）。

* **v1.0.1**
  * Muteki / Pick Item Tracker / Monster Kill Count / アドオンメニュー:
    **ESC キーを押すと表示が消えてしまう**不具合を修正。フレームの土台にしていた
    `chat_memberlist` がゲーム側で「ESC で閉じる」対象（`hideable="true"`）だったのが原因で、
    他のアドオンと同じ `notice_on_pc` 由来に変更した。ESC での非表示は内部の表示状態に
    反映されないため、これまでは次に表示が更新される（アイテムを拾う等）まで戻らなかった。
    メニューボタンは他のアドオンと同じフレーム名を共有しているため、そちらが先に古い定義で
    作っていた場合は、ログイン時に消えない定義へ作り替えるようにもした。
  * Monster Kill Count: **討伐数が一切記録されていなかった不具合を修正。** マップ別の記録を
    保存するフォルダが、旧 klcount アドオンからの移行があるときしか作られておらず、
    新規利用者では保存に毎回失敗していた。
  * Monster Kill Count: **「マップ情報」を開くと討伐数と滞在時間が 0 に戻ってしまう不具合を修正。**
    アイテムを 1 つも拾わなかったマップが「記録なし」と判定され、記録ファイルが
    空の内容で上書きされたうえ一覧からも消えていた。討伐しただけのマップも一覧に出る。
  * Monster Kill Count: 新しく通ったマップが「マップ情報」の一覧に出てこない不具合を修正
    （一覧の元になるマップ一覧が初回起動時にしか作られていなかった）。
    併せて、記録ファイルが古い形式だと設定ボタンが無反応になる不具合も修正。
  * アドオンメニュー: 設定画面の「デフォルトに戻す」「チェックすると上開き」「レイヤー設定」で
    メニューの見た目が変わらなかった不具合を修正（既存フレームを破棄せず作り直そうとしていた）。
    他のアドオンが先にメニューボタンを作っていた場合に、レイヤー変更と位置固定が
    エラーになる不具合も併せて修正。
  * Monster Kill Count: 設定ファイルの内容が欠けていると、アドオンが何も言わずに
    停止してしまう不具合を修正（足りない項目を既定値で補うようにした）。
  * Characters Item Serch: 個人倉庫を閉じたときのアイテム情報保存が一度も動いていなかった不具合を修正
    （フック名 `WAREHOUSE_CLOSE` の先頭にシングルクォートが混入していた）。
    併せて、アイテム情報を 1 つでも取得できなかった場合は、欠けたまま上書きせず
    前回の内容を残すようにした（一部のアイテムが検索から消えるのを防ぐため）。
  * Auto Pet Summon: 設定のキャッシュ判定が別名の変数を見ており、街に入るたび設定ファイルを
    読み直していた不具合を修正。初めて使うキャラクターへキャラチェンジしたときに
    そのキャラの設定が作られず、自動召喚が動かなくなる不具合も併せて修正。
  * アドオン一覧: 登録リストに説明文（翻訳）が無いアドオンがあると一覧フレームごと開けなくなる問題を修正。
    説明が無い場合はアドオン名を表示するようにした。
  * アドオンメニュー: 設定画面（メニューボタンを右クリック）に
    **「詳細なログをシステムに出力する」** を追加。チェックを入れると、初期化したアドオンと
    マップ種別の判定結果をシステムメッセージに出す（不具合報告用。既定は OFF で従来どおり）。
    初期化の行は**有効にしているアドオンのみ**（エラーは無効なものも出す）。
    同じ内容を `addons/_nexus_addons_p/verbose_log.txt` にも書き出すので、
    そのまま不具合報告に添付できる（ログインのたびに作り直すので、中身は常に今回の起動分だけ）。
  * アドオンメニュー: メニューの位置・レイヤー設定の保存先を、他の設定と同じ
    `addons/_nexus_addons_p/<アカウントID>/` 配下へ移動（初回起動時に旧
    `addons/norisan_menu/settings.json` から自動で引き継ぐので、設定し直す必要はない）。
  * 内部改善: 毎フレーム走るフレーム表示チェックの処理を軽くした（マップ種別の取得結果を
    マップ単位でキャッシュし、毎フレームのテーブル生成と文字列連結をやめた）。表示の挙動は変わらない。
    マップ種別を取得できなかった場合はキャッシュせず、取得できるようになった時点で拾い直すため、
    ロード中などに一時的に取得できなくても、そのマップに居る間ずっと判定が壊れることはない。

* **v1.0.0**
  * 本家 Nexus Addons から独立した派生版として、`nexus_addons_p` の名前で配布を開始。
    アドオン名・保存フォルダ・グローバル関数名をすべて `_nexus_addons_p` 系にリネームし、
    バージョンは本家と独立して v1.0.0 から採番。
  * 本家と同時にインストールされている場合、Nexus Addons P 側の機能をすべて停止して
    本家を優先し、チャットで本家の削除を案内するようにした（本家側の動作は壊さない）。
  * 初回起動時、Nexus Addons P 側の設定が無く本家の設定が残っていれば自動で引き継ぐようにした。

  以下は本家 v1.1.6 以降に加えた変更（本家でいう v1.1.7〜v1.1.13）をまとめたもの。

  * Indun Panel / Indun List Viewer / Quickslot Operate: 新レイド「ズメイ」対応。
  * Indun Panel: ログイン時に採掘場(傭兵団)ショップを開いて PVP_MINE 購入可能数を同期していた処理を、
    **パネル展開時の遅延同期**に変更（セッション中1回・完了後に再描画）。これにより、機能を OFF にしていても・
    使っていても**ログイン時に一瞬ウィンドウが開いてインベントリが閉じる不具合**を解消。
    同期でインベントリが閉じた場合は自動復元。
  * Indun Panel: パネルをドラッグで移動しても、閉じる/展開/再ログインで**位置が初期位置に戻る不具合**を修正
    （位置保存ハンドラが「固定」側の分岐に付いていたのを「移動可」側に修正）。
  * Indun List Viewer: 掃討バフお知らせにズメイを追加。新規／旧設定移行ユーザーでレイドが表示されない不具合を修正。
  * Indun List Viewer: ハードモードを持たないレイド向けに nil ガードを追加（新ダンジョンでハードモード不在時のエラーを防止）。
  * Indun List Viewer: ハードモードのないレイド構成で「Hard」ラベルの位置がずれる不具合を修正。
  * Other Character Skill List: 都市入場毎にキャラが消える不具合を修正し、表示をバラック1/2/3ごとにグループ化
    （各バラック内はバラックの並び順どおり）。従来の system_option 基準ではなくバラック名簿基準で整理
    （yoma16版 new_nexus_addons v1.0.6 由来）。※順番の記録には各バラック(1,2,3)へ一度ずつログインが必要。
  * Other Character Skill List: 都市外から設定フレームを開いた際に開けない不具合を修正
    （データ遅延ロード＋描画を pcall で保護。yoma16版 v1.0.5 由来）。
  * Character Change Helper: 装備セットプリセット（3セット）を追加し、コピー/保存をセット単位に刷新
    （yoma16版 v1.0.3/v1.0.4 由来）。
  * Character Change Helper: セット構造が未初期化のキャラでセット切替/セット選択メニューがエラーになる不具合を修正。
    コピー設定の移行時にキー衝突でデータを失う不具合を修正。
  * Guild Event Warp: 画面右上のボタン（ドラグーン／アラクネ姉妹／バウバス）からボスマップへ移動できない不具合を修正
    （削除済みの内部関数呼び出しを、封鎖線ランキングの「移動」と同じ処理に置換）。
  * Guild Event Warp: ボスマップへのワープに移動可否チェックを追加（PVP／レイヤー変更／ダンジョン／レイド地域では不可）。
  * Guild Event Warp: 未知/インスタンスマップでワープ可否チェックがエラーになりワープ機能全体が止まる不具合を修正
    （マップ種別取得の nil ガード）。
  * Auto Repair: 修理キットのアイテム ID 修正（Lv.540→Lv.550）。キットが検出されず繰り返し購入する不具合を修正。
  * Another Warehouse: 設定変更が保存されない不具合を修正。
  * Aethergem Manager: `settings.set` の nil ガードを追加（yoma16版 v1.0.2 由来）。
  * 内部処理: 設定ファイルの保存/読み込みを堅牢化。書き込みをテンポラリファイル経由（tmp + rename）にして破損耐性を向上し、
    保存時の差し替え（rename）失敗を検知して成功と誤報しないよう修正。読み込み時は `.tmp` の内容をデコード成功後に
    差し替えるよう順序を修正し、壊れた一時ファイルを正規ファイルへ昇格させて設定を失う不具合を防止
    （差し替え処理を `atomic_replace` に共通化）。
  * 内部処理: ソースを機能ごとに `nexus_addons_p/src/**` へ分割し、`docs/bundle_from_src.py` で連結ビルドする方式に移行。

</details>

---

## このフォルダの構成

| パス | 内容 |
| --- | --- |
| `src/**` | **source of truth**。編集はここで行う（`core/` + `addons/` + ビルド定義） |
| `src/addons/<key>/` | アドオン 1 つぶん。`<key>.lua`（実装）と `README.md`（使い方）が入る |
| `_nexus_addons_p/` | 配布 bundle の置き場。`.lua` 2 本は生成物（`.gitignore` 済み）、`.xml` は手書き |
| `_nexus_addons_p-⛄-vX.Y.Z.ipf` | 配布物。アドオンマネージャーが取得する実体 |

ビルド手順は [../docs/BUILD_IPF.md](../docs/BUILD_IPF.md)、ソース分割の設計は
[../docs/REFACTOR_SPLIT_DESIGN.md](../docs/REFACTOR_SPLIT_DESIGN.md) を参照。

---

## クレジット

* 元アドオン: [Nexus Addons](https://github.com/ajinorisan/TOSAddon-public) (norisan)
* 一部の修正の取り込み元: [yoma16/tos-addon](https://github.com/yoma16/tos-addon)
* 個別アドオンの原作者は、ゲーム内ヘルプおよび元リポジトリの記載を参照してください。
