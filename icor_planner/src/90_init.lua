-- 単体版の入口。
--
-- **初期化関数の名前はアドオン名を大文字にしたもの**(`_icor_planner` なら
-- `_ICOR_PLANNER_ON_INIT`)。先頭の `_` を落とすと呼ばれず、何も出ない。
--
-- ゲームからのメッセージは自分で購読する(Nexus Addons P の共通基盤は使えない)。
--   GAME_START      … ログイン / マップ移動のたびに来る。ここで組み立て直す
--   ESCAPE_PRESSED  … ESC。中身は共通部品の g.esc_on_escape()
function _ICOR_PLANNER_ON_INIT(addon, frame)
    g.frame = frame
    g.addon = addon
    addon:RegisterMsg("GAME_START", "_ICOR_PLANNER_GAME_START")
    -- **ESC の購読はこの 1 か所だけ。** 開いた窓は g.esc_register で積み、
    -- 閉じるのは一番手前の 1 枚だけにする(shared/src/40_esc.lua)
    addon:RegisterMsg("ESCAPE_PRESSED", "_ICOR_PLANNER_ESCAPE_PRESSED")
end

function _ICOR_PLANNER_ESCAPE_PRESSED()
    g.esc_on_escape()
end

-- ログイン後に 1 回、その後はマップ移動のたびに呼ばれる。
-- **毎回通る前提で書くこと**(二重に掛からないよう、更新スクリプトは掛け直す)。
function _ICOR_PLANNER_GAME_START()
    g.lang = option.GetCurrentCountry()
    g.cid = session.GetMySession():GetCID()
    g.active_id = session.loginInfo.GetAID()
    -- 設定の置き場所。アカウントごとに分ける(キャラごとの選択もこの中)
    g.create_folder(string.format("../addons/%s", "_icor_planner"),
        string.format("../addons/%s/mkdir.txt", "_icor_planner"))
    g.create_folder(string.format("../addons/%s/%s", "_icor_planner", g.active_id),
        string.format("../addons/%s/%s/mkdir.txt", "_icor_planner", g.active_id))
    g.load_core_settings()
    g.icor_planner_settings = nil
    local ok, err = pcall(icor_planner_on_init)
    if not ok then
        ui.SysMsg("{ol}{#FF6347}[IP]{/} 初期化に失敗しました: " .. tostring(err))
        return
    end
    g.register_menu_item()
    g.setup_open_button()
    g.vlog("icor_planner: 初期化した (lang=%s aid=%s cid=%s)", tostring(g.lang), tostring(g.active_id),
        tostring(g.cid))
end

-- Addons Menu(norisan さん系のメニューボタン)へ相乗りする。
--
-- **_G["norisan"]["MENU"] は共有の待ち合わせ場所**で、ここへ {name, func, icon} を入れると
-- メニューを持っているアドオン(Nexus Addons P など)が拾って並べてくれる。
-- 入っていない環境では何も起きないので、チャットコマンド(/icor)も用意してある。
function g.register_menu_item()
    _G["norisan"] = _G["norisan"] or {}
    _G["norisan"]["MENU"] = _G["norisan"]["MENU"] or {}
    _G["norisan"]["MENU"]["Icor Planner"] = {
        name = "Icor Planner",
        func = "Icor_planner_open",
        -- **素に在る画像名を使うこと。** 無い名前だと絵が出ない(利用者は
        -- Addons Menu の設定から好きなアイコンへ変えられる)
        icon = "goddess_type"
    }
end

-- 画面に出しておく小さなボタン。**単体版の入口。**
--
-- 素のクライアントにはアドオンがチャットコマンドを足す仕組みが無い
-- (acutil.slashCommand は別系統のクライアントのもので、こちらの acutil には無い)。
-- Addons Menu(上の相乗り)が入っていない環境でも開けるよう、自前のボタンを出す。
--
-- **常時表示の HUD なので、裏クリックの遮断(g.block_click_through)も ESC のスタックも
-- 使わない。** 塞ぐと画面の一部が押せなくなり、ESC を横取りするとシステムメニューが開けなくなる。
function g.setup_open_button()
    local frame = g.frame or ui.GetFrame("_icor_planner")
    if frame == nil then
        return
    end
    frame:Resize(120, 34)
    local pos = g.settings.button_pos
    if type(pos) == "table" and pos.x and pos.y then
        frame:SetOffset(pos.x, pos.y)
    else
        -- 既定は画面の右上。マーケットや倉庫と重なりにくい位置
        local map_ui = ui.GetFrame("map")
        local screen_w = (map_ui and map_ui:GetWidth()) or 1920
        frame:SetOffset(screen_w - 200, 120)
    end
    -- 掴んで動かせるようにする(位置は閉じるときに覚える)
    frame:EnableHittestFrame(1)
    frame:EnableMove(1)
    local btn = frame:CreateOrGetControl("button", "open_btn", 0, 0, 120, 34)
    AUTO_CAST(btn)
    btn:SetSkinName("tab2_btn")
    btn:SetText(g.lang == "Japanese" and "{@st66b18}イコル計画" or "{@st66b18}Icor Plan")
    btn:SetTextTooltip(g.lang == "Japanese" and
                           "{ol}Icor Planner を開く{nl}{#AAAAAA}掴んで動かせます(位置は覚えます)" or
                           "{ol}Open Icor Planner{nl}{#AAAAAA}Drag to move")
    btn:SetEventScript(ui.LBUTTONUP, "Icor_planner_open")
    btn:ShowWindow(1)
    frame:ShowWindow(1)
    -- 動かした位置を覚える。毎フレームではなく、窓を開いたときに拾う
    g.icor_planner_button_frame = frame
end

-- ボタンの位置を覚える(Icor_planner_open から呼ばれる)
function g.remember_button_pos()
    local frame = g.icor_planner_button_frame
    if frame == nil then
        return
    end
    local x, y = frame:GetX(), frame:GetY()
    local pos = g.settings.button_pos
    if type(pos) == "table" and pos.x == x and pos.y == y then
        return
    end
    g.settings.button_pos = {
        x = x,
        y = y
    }
    g.save_core_settings()
end
