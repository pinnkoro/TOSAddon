# 自作ウィンドウと検索欄の決まり

クリック抜け・ESC・検索欄。どれも「44 アドオン中の大半が間違っていた」実績がある箇所。入口は [CLAUDE.md](../CLAUDE.md)。

## ウィンドウを開いたら裏をクリックできないようにする

**自作ウィンドウを開くコードを書いたら、必ず `g.block_click_through(frame)` を呼ぶこと**
（[core/00_header.lua](../nexus_addons_p/src/core/00_header.lua)。中身は `EnableHittestFrame(1)`）。

土台の `notice_on_pc.xml` は `<input ... hittestframe="false"/>` なので、**既定ではフレーム
自身の背景（コントロールが乗っていない余白）が当たり判定を持たない**。そこを押した入力は
下の 3D 画面へ抜け、窓の上を押したつもりでキャラクターが歩き出す・敵を選ぶ、という動きになる。
子のボタンやスロットは各自の `EnableHitTest` で受けるので、**余白を押したときだけ裏に通る**
という一番分かりにくい形で出る（実際に 44 アドオン中 26 個の窓がこの作りだった）。

* **`EnableMove` と相乗りさせないこと。** 「フレームを固定」は**動かさない**だけの設定で、
  当たり判定まで捨てる意味はない。`indun_panel` が `EnableHittestFrame(enable)` と
  `EnableMove(enable)` を同じ変数で切り替えており、**固定にした利用者だけ**展開表示
  （横 600px 以上）の上を押すと裏へ抜けていた。
* **呼んではいけないもの**（塞ぐと画面の一部が押せなくなる）
  * 常時表示の HUD（`always_status` / `muteki` / `monster_kill_count` のように、
    利用者の「固定」「ロック」設定で通す/通さないを切り替える作りのもの）
  * マーカー（`party_marker` / `boss_direction` の矢印）、ツールチップ
  * 大きさ 0 の入れ物フレーム（`mini_addons` の `RunUpdateScript` 用の土台など）
* 呼び忘れは [docs/check_frame_hittest.py](check_frame_hittest.py) が落とす（CI の
  `bundle` ジョブでも走る）。上の「通したいもの」はスクリプトの `ALLOW` へ**理由付きで**
  足すこと。ALLOW に残骸（該当のフレーム生成が無いキー）が残っていても落ちる。

## ウィンドウを開いたら ESC で閉じられるようにする

**自作ウィンドウを開くコードを書いたら、必ず `g.esc_register` 系でスタックへ積むこと。**
土台に使っている `notice_on_pc`（`g.create_persistent_frame` も同じ）はゲーム側の ESC では
消えないので、積み忘れたウィンドウは**ESC が完全に無反応**になる。利用者から見ると
「閉じるものと閉じないものがある」という一番分かりにくい形で出る（実際に 44 アドオン中
4 つしか積んでいない時期があり、設定画面のほとんどが ESC で閉じなかった）。

* **まず × ボタンの中身を読むこと。** 選ぶ基準は土台ではなく**× が何をしているか**。
  * `g.esc_register(frame_name, close)` … × が破棄以外の後始末もしているとき。
    `close` はグローバル関数の**名前**（引数無しで呼べること）でも**関数そのもの**でもよい。
    閉じる処理がフレームを引数に取る作りなら、無名関数で包んで渡す
  * `g.esc_register_destroy(frame_name)` … × も `ui.DestroyFrame` だけのとき
  * `g.esc_register_hide(frame_name)` … × も破棄せず隠すとき（`CreateNewFrame` で
    作り直せない土台、参照を持ち回しているウィンドウ）
  * `g.esc_register_keep(frame_name, close)` … 下記「作り直す初期化関数から積むとき」
  * 実装は [core/00_header.lua](../nexus_addons_p/src/core/00_header.lua)
* **ESC は × ボタンと同じ挙動にする。** × が保存やインベントリの右クリック割り当ての
  復帰までやっているなら、ESC からも同じ関数を通すこと。片方だけ後始末が抜けると、
  「× なら直るのに ESC だと壊れる」という追いにくい差になる。
  * 実例: `cc_helper` の × は `INVENTORY_SET_CUSTOM_RBTNDOWN` を状況に応じて戻している。
    ここを `esc_register_destroy` にすると、ESC で閉じた後もインベントリの右クリックが
    そのアドオンに割り当てられたまま残る（レビューで指摘されて直した）。
* **開いた直後に入力欄へ `Focus()` しないこと。** キーボードフォーカスが入力欄にあると、
  ESC の 1 回目はクライアント側の「入力欄から抜ける」処理に使われ、`ESCAPE_PRESSED` が
  **こちらへ届かない**（`verbose_log.txt` に行が 1 つも出ないので、押下が届いていないことは
  ログで確かめられる）。利用者から見ると「2 回押さないと閉じない」になる。横取りする手段は
  無いので、フォーカスを取らないことでしか直せない。
  * 実例: `easy_buff` の設定画面はプリセット 1 の名前欄へ `Focus()` していて、この形で出た。
  * 検索窓のように**入力が主目的の窓**だけは、利便性を取って残してよい（`tavern_of_soul`）。
    その場合 ESC が 2 回要ることは承知のうえで残すこと。
* **呼ぶのは `ShowWindow(1)` の後。** まだ出ていない状態で積むと、直後の同期で
  「閉じ終わった登録」と見なされてその場で捨てられる。
  * 「開いたら必ず通る」場所であることも確かめる。`ShowWindow(1)` の直後でも、
    そこを通らずに窓が出る経路があれば積み漏れる（`market_favorite_rebuild` の
    自動表示は `TOGGLE_FRAME("true")` の後に呼び元が `ShowWindow(1)` する）。
* **中身を作り直す初期化関数から積むときは `g.esc_register_keep`。**
  `esc_register` は「開き直し = 最前面」なので、**子の一覧を開いたまま親の設定画面を
  組み立て直す**作り（`battle_ritual` / `muteki` はスキルやバフを足すたびに設定画面の
  初期化関数を呼び直す）でこれを使うと、親が子より手前へ積み直され、ESC 1 回で
  親の close が走って子まで道連れになる。積むのは**窓そのものを開く関数**に置き、
  行やタブを作るような**繰り返し呼ばれる関数の中に入れないこと**。
* **積んではいけないもの**（積むと ESC を常に横取りしてシステムメニューが開けなくなる）
  * 常時表示の HUD（`indun_panel` / `always_status` / ボタン類、`_nexus_addons_p_update_frames`
    の `update_check_frames` に載っているフレームは毎フレーム復帰させるので特にだめ）
  * ツールチップ、マーカーなど利用者が「閉じる」と認識しないもの
  * **ゲーム側のウィンドウに貼り付いている付属パネル**（`bulk_sales` は shop、
    `ancient_auto_set` は ancient_card_list、`another_warehouse` の本体は accountwarehouse に
    連動して開閉する）。ここで ESC を横取りすると、本来閉じるべきゲーム側の窓が
    開いたまま残る。親のゲーム窓が閉じるときに一緒に畳まれる作りにしておくこと
* 判定と close の呼び出しは `_nexus_addons_p_ESCAPE_PRESSED`（[core/20_lifecycle.lua](../nexus_addons_p/src/core/20_lifecycle.lua)）
  1 箇所に集約してある。**アドオン側で `ESCAPE_PRESSED` を個別に購読しないこと**
  （各自が自分のフレームを閉じると、1 回の ESC で開いている自作ウィンドウが全部消える）。

## 検索欄は 2 つの共通部品のどちらかを使う

**検索欄を作ったら、必ず次のどちらかを呼ぶこと**（[core/00_header.lua](../nexus_addons_p/src/core/00_header.lua)）。
`ui.ENTERKEY` の割り当ての直後に置く。どちらを使っても、
**入力があるときだけ虫眼鏡ボタンの左隣に「×」が出る**（登録すれば自動で付くので、
アドオン側でボタンを作らないこと）。ENTERKEY と虫眼鏡ボタンはどちらの場合も残す。

| | `g.setup_incremental_search` | `g.setup_enter_search` |
| --- | --- | --- |
| 検索するきっかけ | **打鍵のたび**（+ Enter / 虫眼鏡） | **Enter / 虫眼鏡だけ** |
| 「×」を押したとき | 検索関数を**空文字で呼ぶ**（= 全件へ戻す） | 渡した**初期化関数**を呼ぶ（= 検索前の姿へ畳む） |
| 使う場面 | **既に手元にある一覧を絞る**検索 | **全件を走査して当たったぶんだけ作る**検索 |

### 選び方

判断の基準はひとつだけ。**空文字で検索関数を呼んだときに何が起きるか**を見る。

* **空文字 = 元の一覧が出るだけ**なら `g.setup_incremental_search`。
  絞り込みなので 1 文字ごとに走らせても作る量は増えず、消せば戻る。
* **空文字 = 全件に当たってしまう**なら `g.setup_enter_search`。
  `string.find(name, "", 1, true)` は必ず真なので、`GetClassList` の全件を回して
  一致したぶんだけコントロールを作る作りだと、**空でも 1 文字でも数千〜数万件を組み立てる**。
  打鍵検索も「×で空文字検索」も成立しないので、こちらを使う。
  * 実例: `tavern_of_soul` の `Tavern_of_soul_get_data`。件数の上限も無い。

### 使い方

```lua
-- (1) 一覧を絞る検索
search_edit:SetEventScript(ui.ENTERKEY, "Xxx_search")
search_edit:SetEventScriptArgNumber(ui.ENTERKEY, index)   -- 無ければ省略
g.setup_incremental_search(search_edit, "Xxx_search", index)
--   第 4 引数で打鍵から検索までの秒数を伸ばせる（既定 0.3 秒。`another_warehouse` は 0.5 秒）

-- (2) 全件を走査する検索
search_edit:SetEventScript(ui.ENTERKEY, "Xxx_search")
g.setup_enter_search(search_edit, "Xxx_clear")
--   Xxx_clear は **空文字で検索し直す処理ではなく**、検索前の姿へ戻す処理にすること
--   （入力を消す・結果を捨てる・窓の大きさを戻す）。呼び出しの並びは検索関数と同じ
```

### 共通の注意

* **検索欄の文字をコードから変えたら `g.search_clear_sync(edit)` を呼ぶこと。** 理由は 2 つある。
  1. 「×」の出し入れは打鍵でしか起きないので、呼ばないと空なのに「×」が残る／文字があるのに出ない
  2. 「前回この語で検索した」の記録を捨てる。打鍵検索は同じ語なら検索を飛ばすので、捨てないと
     **コードで空へ戻した後に利用者が同じ語を打ち直しても検索が走らない**
  タブ切り替えで空へ戻す `another_warehouse`、組み立て直しで入れ直す `separate_buff_custom`、
  一覧を作り直す `_nexus_addons_p_frame_init` がこれに当たる。
* **今と同じ文字列を `SetText` で入れ直さないこと。** 同じ文字列でも入力位置が戻るので、
  打っている最中にカーソルが飛び、日本語変換も壊れる。Lua では `""` も真なので
  `if ctrl_text then SetText(ctrl_text) end` は常に成立する点に注意
  （`separate_buff_custom` が実際にこの形で、打鍵のたびにカーソルが飛んでいた）。
* **一覧を畳む／初期化する処理に窓の位置戻しを混ぜないこと。** 「×」からも呼ばれるので、
  利用者が動かした窓が押すたびに初期位置へ飛ぶ（`tavern_of_soul` で実際にそうなっていた）。
* **「×」から `Focus()` を戻さないこと。** 入力欄にキーボードフォーカスがあると ESC の
  1 回目が「入力欄から抜ける」に使われ、窓が閉じなくなる（下記 ESC の節と同じ理由）。
  打鍵で空になった経路だけ `Focus()` を戻したいときは `g.search_typing_running` を見る
  （打鍵から検索関数を呼んでいる間だけ真）。**「打鍵以外を弾く」向きに書くこと。**
  検索関数には打鍵のほかに Enter・虫眼鏡ボタン・「×」から入ってくるので、
  「×から来たか」だけを見る書き方だと虫眼鏡ボタン経由を取りこぼす。
* **検索語は `ctrl:GetText()` ではなく検索欄を名前で引いて読むこと。** 同じ関数を虫眼鏡ボタンにも
  割り当てているので、`ctrl` がボタンのときは空文字を検索語にしてしまう
  （`another_warehouse` が実際にこの形で「押すと検索が解除される」不具合になっていた）。
* **一覧の作り直しで検索欄そのものを壊さないこと。** 検索欄は `if not frame` の中で 1 回だけ作り、
  検索のたびに作り直すのは中身の groupbox だけにする。検索欄ごと作り直すと、打鍵の途中で
  入力位置と文字が消えて打ち直しになる。やむを得ず作り直す経路（`characters_item_serch` は
  空に戻したとき `frame_init` を通る）では、作り直した検索欄へ `Focus()` を戻すこと。

### 素のクライアントはどうなっているか（調査済み・繰り返さないこと）

`_client/jp/addon.ipf/**/*.xml` の `<edit>` を全部数えた結果。**素は Enter 方式が多数派**で、
打鍵のたびに検索するのは一部だけ。「素がそうだから」を理由に一方へ寄せないこと。

* **打鍵のたびに検索（`typingscp` あり）… 9 個** — inventory / item_cabinet の `ItemSearch`、
  worldmap2_mainmap・worldmap2_submap の `search_edit`、guildinfo の `memberSearch`、
  housing_shop、bgmplayer、party_search_board、colony_tax_distribute
* **Enter だけ … 32 個** — adventure_book（8 個）/ quest / collection / friend / tpitem（5 個）/
  cheatlist / worldmap（旧）/ guild_dress_room / halloffame / status の名声検索 など

**素には「検索欄をクリアするボタン」が無い。**「×」はこちらで足したもので、素に倣ったものではない
（一般的な検索窓の作法に寄せている）。`market_reset*_btn` というリセット用のアイコンは在るが、
使われているのは一覧の再取得と `inventoryoption` のフィルタ条件のリセットで、検索文字列のクリアではない。

**虫眼鏡ボタンの意味は場所による。**

* inventory では、ボタン・Enter・打鍵が**同じ `SEARCH_ITEM_INVENTORY` を呼ぶ**。中で数えている
  `searchEnterCount`（同じ語で押した回数）は**クライアント全体のどこからも読まれていない**ので、
  現行では死んだコード＝ボタンは打鍵と同じことをするだけ。
* worldmap2 では**別物**。打鍵の `WORLDMAP2_SEARCH_UPDATE` は候補一覧を出すだけ、
  Enter の `WORLDMAP2_SEARCH` は最初に一致したマップへ実際に飛ぶ（3 文字以下は無視）。
  「絞り込み」と「決定」で役割が分かれている作りが要るときは、こちらを参考にする。

実物は次で読める。**同じ調査を繰り返さないこと。**

```
git show upstream/main:_client/jp/addon.ipf/inventory/inventory.xml     # typingscp="SEARCH_ITEM_INVENTORY_KEY"
git show upstream/main:_client/jp/addon.ipf/inventory/inventory.lua     # CancelReserveScript / ReserveScript(0.3)
git show upstream/main:_client/jp/ui.ipf/uiscp/worldmap2_uiscp_search.lua
```

### 実装側のメモ

* グローバルの `ReserveScript(式文字列, 秒)` には**取り消しが無い**（素は `frame:CancelReserveScript`
  を使うが、フレーム側の予約は「フレームごとに関数名 1 つ」なので、同じフレームに検索欄が
  複数ある作り（`battle_ritual`）だと打ち消し合う）。そのため検索欄ごとに世代番号を持ち、
  最後の打鍵の分だけ実行して残りは捨てている。
* 打鍵から実行までの間に × ボタンで窓を閉じられることがあるので、**検索欄の参照を持ち回さず**
  フレーム名とコントロール名から引き直す。
* 「×」の位置決めは**作成時ではなく最初に表示するとき**に行う。虫眼鏡ボタン（`search_btn`）は
  どのアドオンでも検索欄より後に作られ、登録時点では幅を読めないため。
