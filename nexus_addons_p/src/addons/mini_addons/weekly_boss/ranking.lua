-- ボスレランキング ここから
local base_jobids = {1001, 2001, 3001, 4001, 5001}
local processed_job_ids = {}
local result_tbl = {}
local existing_data_check = {}
local start_time = 0
function Mini_addons_INDUNINFO_UI_CLOSE()
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    if rankListBox:HaveUpdateScript("Mini_addons_get_weekly_boss_data") == false then
        return
    end
    rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_data")
    rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_damage")
    local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
    induninfo_class_selector:SetEnable(1)
    local msg = g.lang == "Japanese" and
                    "データ取得処理を終了します{nl}データは保存出来ていません" or
                    "Data acquisition process terminated{nl}The data could not be saved"
    imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 3.0)
end

function Mini_addons_WEEKLYBOSS_PATTERNINFO_UI_UPDATE(frame, msg, str, num)
    if g.settings.boss_rank == 0 then
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rank_gb = GET_CHILD_RECURSIVELY(induninfo, "rank_gb")
    local data_btn = rank_gb:CreateOrGetControl("button", "data_btn", -4, 300, 52, 52)
    AUTO_CAST(data_btn)
    data_btn:SetSkinName("None")
    data_btn:SetText("{img indun_season_tap 52 52}")
    local tooltip = g.lang == "Japanese" and "{ol}データ取得" or "{ol}Data Acquisition"
    data_btn:SetTextTooltip(tooltip)
    local data_btn_text = data_btn:CreateOrGetControl("richtext", "data_btn_text", 10, 15, 0, 20)
    AUTO_CAST(data_btn_text)
    data_btn_text:SetText("{ol}data")
    data_btn_text:SetTextTooltip(tooltip)
    data_btn_text:SetEventScript(ui.LBUTTONUP, "Mini_addons_get_weekly_boss_data_context")
    data_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_get_weekly_boss_data_context")
    local rank_btn = rank_gb:CreateOrGetControl("button", "rank_btn", -4, 354, 52, 52)
    AUTO_CAST(rank_btn)
    rank_btn:SetSkinName("None")
    rank_btn:SetText("{img indun_season_tap 52 52}") -- tab2
    local tooltip = g.lang == "Japanese" and "{ol}ランキング表示" or "{ol}Show Leaderboard"
    rank_btn:SetTextTooltip(tooltip)
    local rank_btn_text = rank_btn:CreateOrGetControl("richtext", "rank_btn_text", 10, 15, 0, 20)
    AUTO_CAST(rank_btn_text)
    rank_btn_text:SetText("{ol}rank")
    rank_btn_text:SetTextTooltip(tooltip)
    rank_btn_text:SetEventScript(ui.LBUTTONUP, "Mini_addons_create_ranking_data")
    rank_btn:SetEventScript(ui.LBUTTONUP, "Mini_addons_create_ranking_data")
end

function Mini_addons_create_ranking_data()
    local induninfo = ui.GetFrame("induninfo")
    local file_path = g.boss_rank_log_path
    local log_data = g.load_dat(file_path)
    if not log_data then
        local msg = g.lang == "Japanese" and
                        "ランキングデータが未取得です{nl}ランキングデータを取得してください" or
                        "Ranking data has not been acquired{nl}Please acquire the ranking data"
        ui.SysMsg(msg)
        return
    end
    local week_num = session.weeklyboss.GetNowWeekNum()
    local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
    local season_index = season_tab:GetSelectItemIndex()
    local season = week_num - season_index
    local is_save = true
    local checked_jobs = {}
    local all_derived_jobs = {}
    local function get_base_jobid_local(job_cls_id)
        if not job_cls_id then
            return nil
        end
        return job_cls_id - (job_cls_id % 1000) + 1
    end
    for _, base_id in ipairs(base_jobids) do
        local job_list = GET_JOB_LIST(base_id)
        for _, job_cls in ipairs(job_list) do
            local job_id = TryGetProp(job_cls, "ClassID", 0)
            if job_id ~= 0 and job_id % 100 ~= 1 then
                all_derived_jobs[job_id] = false -- チェックリストをfalseで初期化
            end
        end
    end
    for _, record in ipairs(log_data) do
        local week_num_ = tonumber(record[1])
        if week_num_ == season then
            local job_id = tonumber(record[2])
            local is_confirmed_str = record[7]
            if is_confirmed_str == "false" then
                is_save = false
                break
            end
            if all_derived_jobs[job_id] ~= nil then
                all_derived_jobs[job_id] = true
            end
        end
    end
    if is_save then
        for job_id, checked in pairs(all_derived_jobs) do
            if not checked then
                is_save = false
                break
            end
        end
    end
    local player_data = {}
    for _, record in ipairs(log_data) do
        local week_num_ = tonumber(record[1])
        if week_num_ == season then
            local job_id = tonumber(record[2])
            local name = record[4]
            local damage = tonumber(record[5])
            if not player_data[name] then
                player_data[name] = {
                    all_jobs = {},
                    max_damage = 0
                }
            end
            if #player_data[name].all_jobs < 4 then
                local found = false
                for _, existing_id in ipairs(player_data[name].all_jobs) do
                    if existing_id == job_id then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(player_data[name].all_jobs, job_id)
                end
            end
            if damage > player_data[name].max_damage then
                player_data[name].max_damage = damage
            end
        end
    end
    local ranking_list = {}
    for name, data in pairs(player_data) do
        table.insert(ranking_list, {
            name = name,
            damage = data.max_damage,
            all_jobs = data.all_jobs
        })
    end
    -- ファイルはあるのに、週タブで選んでいる週のデータだけが無いとき。
    -- 「未取得です」だけだと保存の失敗と見分けが付かない(週が替わった直後に「今週」の
    -- タブのまま開くと必ずこうなり、保存先を移した直後の実機確認で取り違えかけた)。
    -- どの週を探して、どの週なら持っているのかを出す。
    if #ranking_list == 0 then
        local weeks_set, weeks = {}, {}
        for _, record in ipairs(log_data) do
            local w = tonumber(record[1])
            if w and not weeks_set[w] then
                weeks_set[w] = true
                table.insert(weeks, w)
            end
        end
        table.sort(weeks)
        local weeks_str = #weeks > 0 and table.concat(weeks, ", ") or "-"
        core_g.vlog("boss_rank: [%s] 週のデータが無い (保存済みの週: %s / %s)", tostring(season), weeks_str,
            tostring(g.boss_rank_log_path))
        local msg = g.lang == "Japanese" and
                        string.format("[%s] 週のランキングデータがありません{nl}保存済みの週: %s{nl}週のタブを切り替えるか、データを取得してください",
                tostring(season), weeks_str) or
                        string.format("No ranking data for week [%s]{nl}Saved weeks: %s{nl}Switch the week tab or acquire the data",
                tostring(season), weeks_str)
        ui.SysMsg(msg)
        return
    end
    table.sort(ranking_list, function(a, b)
        return a.damage > b.damage
    end)
    local display_data_list = {}
    for i, data in ipairs(ranking_list) do
        if i > 100 then
            break
        end
        local base_job_id = nil
        local derived_jobs = {}
        local base_id_counts = {}
        for _, job_id in ipairs(data.all_jobs) do
            if job_id % 100 == 1 then
                base_job_id = job_id
            else
                table.insert(derived_jobs, job_id)
                local b_id = get_base_jobid_local(job_id)
                if b_id then
                    base_id_counts[b_id] = (base_id_counts[b_id] or 0) + 1
                end
            end
        end
        if not base_job_id and #derived_jobs > 0 then
            local max_count = 0
            for b_id, count in pairs(base_id_counts) do
                if count > max_count then
                    max_count = count
                    base_job_id = b_id
                end
            end
        end
        local build_parts = {}
        if base_job_id then
            table.insert(build_parts, base_job_id)
        end
        for _, job_id in ipairs(derived_jobs) do
            table.insert(build_parts, job_id)
        end
        table.insert(display_data_list, {
            season = season,
            rank = i,
            name = data.name,
            damage = data.damage,
            build = build_parts
        })
        local build_str = table.concat(build_parts, ", ")
    end
    Mini_addons_create_ranking_data_frame(display_data_list, is_save)
end

-- ESC 用の入口。理由は Mini_addons_setting_ESCAPE_PRESSED と同じ。
function Mini_addons_ranking_ESCAPE_PRESSED()
    local rank_frame = ui.GetFrame(addon_name_lower .. "rank_frame")
    if rank_frame then
        Mini_addons_ranking_close(rank_frame)
    end
end

function Mini_addons_ranking_close(frame)
    local frame_name = frame:GetName()
    ui.DestroyFrame(frame_name)
end

function Mini_addons_create_ranking_data_frame(ranking_data, is_save)
    if not ranking_data or #ranking_data == 0 then
        local msg = g.lang == "Japanese" and
                        "ランキングデータが未取得です{nl}ランキングデータを取得してください" or
                        "Ranking data has not been acquired{nl}Please acquire the ranking data"
        ui.SysMsg(msg)
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rank_frame = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "rank_frame", 0, 0, 0, 0)
    AUTO_CAST(rank_frame)
    rank_frame:SetSkinName("test_frame_low")
    rank_frame:SetLayerLevel(102)
    rank_frame:EnableHittestFrame(1)
    -- 上流は EnableMove を呼んでおらず動かせなかったので P 側で足した
    -- (位置の保存はしないため、開き直すと既定位置に戻る)
    rank_frame:EnableMove(1)
    rank_frame:ShowTitleBar(0)
    rank_frame:RemoveAllChild()
    local season = ranking_data[1].season
    local status_text = ""
    if is_save == false then
        status_text = " (Unconfirmed)"
    else
        status_text = " (Confirmed)"
    end
    local title = rank_frame:CreateOrGetControl("richtext", "title", 30, 10)
    AUTO_CAST(title)
    title:SetText("{@st66b18}Weekly Ranking [" .. season .. "] week" .. status_text)
    local gbox = rank_frame:CreateOrGetControl("groupbox", "gbox", 10, 30, 0, 0)
    AUTO_CAST(gbox)
    gbox:SetSkinName("bg")
    local close = rank_frame:CreateOrGetControl("button", "close", 0, 0, 30, 30)
    AUTO_CAST(close)
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetImage("testclose_button")
    close:SetEventScript(ui.LBUTTONUP, "Mini_addons_ranking_close")
    local y = 10
    local max_rank_width = 0
    local max_name_width = 0
    local max_damage_width = 0
    local temp_rank_text = gbox:CreateOrGetControl("richtext", "temp_rank", 0, 0)
    temp_rank_text:SetText("100.")
    max_rank_width = temp_rank_text:GetWidth()
    temp_rank_text:ShowWindow(0)
    for i, data in ipairs(ranking_data) do
        local temp_name_text = gbox:CreateOrGetControl("richtext", "temp_name_" .. i, 0, 0)
        temp_name_text:SetText("{ol}" .. data.name)
        if temp_name_text:GetWidth() > max_name_width then
            max_name_width = temp_name_text:GetWidth()
        end
        temp_name_text:ShowWindow(0)
        local temp_damage_text = gbox:CreateOrGetControl("richtext", "temp_damage_" .. i, 0, 0)
        temp_damage_text:SetText(string.format("Damage: %d", data.damage))
        if temp_damage_text:GetWidth() > max_damage_width then
            max_damage_width = temp_damage_text:GetWidth()
        end
        temp_damage_text:ShowWindow(0)
    end
    local rank_col_x = 10
    local name_col_x = rank_col_x + max_rank_width
    local icon_col_x = name_col_x + max_name_width
    local damage_col_x = icon_col_x + (4 * 25) - 10
    for i, data in ipairs(ranking_data) do
        local rank_text = gbox:CreateOrGetControl("richtext", "rank_" .. i, rank_col_x, y)
        AUTO_CAST(rank_text)
        rank_text:SetText("{ol}" .. string.format("%d.", data.rank))
        local name_text = gbox:CreateOrGetControl("richtext", "name_" .. i, name_col_x, y)
        AUTO_CAST(name_text)
        name_text:SetText("{ol}" .. data.name)
        local icon_x = icon_col_x
        for j, job_id in ipairs(data.build) do
            if j > 4 then
                break
            end
            local job_cls = GetClassByType("Job", job_id)
            if job_cls then
                local job_icon = gbox:CreateOrGetControl("picture", "job_icon_" .. i .. "_" .. j, icon_x, y - 5, 25, 25)
                AUTO_CAST(job_icon)
                job_icon:SetImage(job_cls.Icon)
                job_icon:SetEnableStretch(1)
                job_icon:EnableHitTest(1)
                job_icon:SetTooltipType("adventure_book_job_info")
                job_icon:SetTooltipArg(job_id, 0, 0)
                icon_x = icon_x + 25
            end
        end
        local damage_text = gbox:CreateOrGetControl("richtext", "damage_" .. i, damage_col_x, y)
        AUTO_CAST(damage_text)
        damage_text:SetText("{ol}" .. GET_COMMAED_STRING(data.damage))
        local text_width = damage_text:GetWidth()
        local centered_x = damage_col_x + (max_damage_width - text_width) / 2
        damage_text:SetPos(centered_x, y)
        y = y + 30
    end
    local max_x = damage_col_x + max_damage_width
    rank_frame:SetPos(induninfo:GetX() + 20, induninfo:GetY() + 20)
    rank_frame:Resize(max_x + 20, 550)
    gbox:Resize(rank_frame:GetWidth() - 20, rank_frame:GetHeight() - 40)
    gbox:EnableScrollBar(1)
    gbox:SetScrollPos(0)
    rank_frame:ShowWindow(1)
    core_g.esc_register(addon_name_lower .. "rank_frame", "Mini_addons_ranking_ESCAPE_PRESSED")
end

function Mini_addons_get_weekly_boss_data_context(frame, ctrl, str, num)
    -- 見出し行を置かないこと。コンテキストメニューには押せない行を作る手段が無く
    -- (素の ui.AddContextMenuItem は全行が選択肢になる)、以前の "four weeks" / "This week" の
    -- 見出しは押せてしまっていた。代わりに各行の頭へ「今週 / 4週分」を付けて、
    -- 期間ごとに色を分ける。よく使う「今週」を上に、各期間の先頭に「全職業」を置く。
    local is_jp = g.lang == "Japanese"
    local title = is_jp and "{ol}ランキングデータの取得" or "{ol}Acquire Ranking Data"
    local context = ui.CreateContextMenu("weekly_boss_data", title, 0, 0, 0, 0)
    -- mode_base: 全職業のときに Mini_addons_get_weekly_boss_data_reserve へ渡す値(今週 0 / 4週分 1)
    local periods = {{
        label = is_jp and "今週" or "This week",
        color = "{#FFFFFF}",
        is_four_weeks = 0,
        mode_base = 0,
        sec_all = 150,
        sec_one = 30
    }, {
        label = is_jp and "4週分" or "4 weeks",
        color = "{#9FD8FF}",
        is_four_weeks = 1,
        mode_base = 1,
        sec_all = 600,
        sec_one = 120
    }}
    for _, p in ipairs(periods) do
        local head = "{ol}" .. p.color .. p.label .. " / "
        local all_text = is_jp and string.format("%s全職業 (約%d秒)", head, p.sec_all) or
                             string.format("%sAll classes (about %d sec)", head, p.sec_all)
        ui.AddContextMenuItem(context, all_text,
            string.format("Mini_addons_get_weekly_boss_data_reserve(%d, %d)", p.mode_base, p.is_four_weeks))
        for i = 1, #base_jobids do
            local job_cls = GetClassByType("Job", base_jobids[i])
            local text = is_jp and string.format("%s%s (約%d秒)", head, job_cls.Name, p.sec_one) or
                             string.format("%s%s (about %d sec)", head, job_cls.Name, p.sec_one)
            ui.AddContextMenuItem(context, text,
                string.format("Mini_addons_get_weekly_boss_data_reserve(%d, %d)", base_jobids[i], p.is_four_weeks))
        end
    end
    local prune_on = g.settings.boss_rank_prune == 1
    local mark = (prune_on and "{#00FF00}[ON]" or "{#AAAAAA}[OFF]") .. "{#FFFFFF}"
    local prune_text = is_jp and "{ol}" .. mark .. " 4週より古いデータを自動で削除" or "{ol}" .. mark ..
                           " Auto-delete data older than 4 weeks"
    ui.AddContextMenuItem(context, prune_text, "Mini_addons_toggle_boss_rank_prune()")
    ui.OpenContextMenu(context)
end

function Mini_addons_save_log()
    local file_path = g.boss_rank_log_path
    local existing_records = g.load_dat(file_path) or {}
    local new_records_check = {}
    for _, new_record in ipairs(result_tbl) do
        local week_str = tostring(new_record[1])
        local job_id_str = tostring(new_record[2])
        if not new_records_check[week_str] then
            new_records_check[week_str] = {}
        end
        new_records_check[week_str][job_id_str] = true
    end
    local final_records_to_save = {}
    if #existing_records > 0 then
        for _, old_record in ipairs(existing_records) do
            local old_week_str, old_job_id_str = old_record[1], old_record[2]
            if not (new_records_check[old_week_str] and new_records_check[old_week_str][old_job_id_str]) then
                table.insert(final_records_to_save, old_record)
            end
        end
    end
    for _, new_record in ipairs(result_tbl) do
        table.insert(final_records_to_save, new_record)
    end
    final_records_to_save = Mini_addons_prune_boss_rank_records(final_records_to_save)
    local lines_to_write = {}
    for _, record in ipairs(final_records_to_save) do
        table.insert(lines_to_write, table.concat(record, ":::"))
    end
    local content_to_write = table.concat(lines_to_write, "\n")
    -- 失敗を黙って捨てないこと。以前は保存先のフォルダが無くて毎回失敗していたのに、
    -- 「保存しました」「処理が完了しました」だけが出て、表示しようとして初めて
    -- 「未取得です」と言われる形でしか表に出なかった(利用者からの報告で発覚)。
    local file, err = io.open(file_path, "w")
    if not file then
        core_g.vlog("{#FF6347}boss_rank: log 保存 FAILED{/} %s (%s)", file_path, tostring(err))
        return false
    end
    file:write(content_to_write)
    file:close()
    core_g.vlog("boss_rank: log 保存 %s (%d 行)", file_path, #lines_to_write)
    return true
end

-- 設定 boss_rank_prune が ON のとき、今週を含めて 4 週(= 今週と前の 3 週。「4週分」の取得と
-- 同じ範囲)より古い週の行を落とす。OFF のときは受け取ったものをそのまま返す。
-- 今の週番号が取れないとき(0 / nil)は、何週目まで残すか決められないので消さない。
function Mini_addons_prune_boss_rank_records(records)
    if not g.settings or g.settings.boss_rank_prune ~= 1 then
        return records
    end
    local now_week = tonumber(session.weeklyboss.GetNowWeekNum())
    if not now_week or now_week <= 0 then
        core_g.vlog("boss_rank: 週番号が取れないので古い週を消さない (%s)", tostring(now_week))
        return records
    end
    local oldest_kept = now_week - 3
    local kept, dropped_weeks = {}, {}
    for _, record in ipairs(records) do
        local w = tonumber(record[1])
        if w and w < oldest_kept then
            dropped_weeks[w] = (dropped_weeks[w] or 0) + 1
        else
            table.insert(kept, record)
        end
    end
    local dropped = #records - #kept
    if dropped > 0 then
        local weeks = {}
        for w in pairs(dropped_weeks) do
            table.insert(weeks, w)
        end
        table.sort(weeks)
        core_g.vlog("boss_rank: %d 週より古い週を削除 週=%s (%d 行)", oldest_kept, table.concat(weeks, ","), dropped)
    end
    return kept
end

-- data ボタンのメニューから呼ぶ。コンテキストメニューには本物のチェックボックスを置けないので、
-- 行の頭に [ON] / [OFF] を出して、押すたびに切り替える。
-- **切り替えた時点では消さない。** メニューの押し間違いでデータが消えないよう、実際に消すのは
-- 次に保存するとき(Mini_addons_save_log)だけにしている。
function Mini_addons_toggle_boss_rank_prune()
    g.settings.boss_rank_prune = g.settings.boss_rank_prune == 1 and 0 or 1
    Mini_addons_save_settings()
    core_g.vlog("boss_rank: boss_rank_prune=%d", g.settings.boss_rank_prune)
    local msg
    if g.settings.boss_rank_prune == 1 then
        msg = g.lang == "Japanese" and
                  "4週より古いデータの自動削除: ON{nl}次にデータを保存するときから、4週より古い週を削除します" or
                  "Auto-delete data older than 4 weeks: ON{nl}Weeks older than 4 weeks will be deleted from the next save"
    else
        msg = g.lang == "Japanese" and "4週より古いデータの自動削除: OFF{nl}データは削除しません" or
                  "Auto-delete data older than 4 weeks: OFF{nl}No data will be deleted"
    end
    ui.SysMsg(msg)
end

-- ランキングの保存先を AID フォルダへ移したので(g.update_paths のコメント)、旧パスから 1 回だけ写す。
-- 探す順:
--   1. ../addons/mini_addons_p/log.dat … 同梱版自身の旧保存先。**設定の引き継ぎ
--      (core の migrate_individual_addon_settings)では "_p" のフォルダを引き継ぎ元にしない
--      決まりだが、log.dat は正真正銘ここにしか無かったので例外。**
--   2. ../addons/mini_addons/log.dat … 本家の個別版。行の形式(week:::job:::順位:::名前:::
--      ダメージ:::職業名:::確定)は同じなので、そのまま写せる。
-- 写した後も元のファイルは消さない(個別版に戻したときにそのまま使えるように)。
function Mini_addons_migrate_boss_rank_log()
    local dst_path = g.boss_rank_log_path
    if not dst_path or g.boss_rank_log_checked == dst_path then
        return
    end
    g.boss_rank_log_checked = dst_path
    local dst = io.open(dst_path, "r")
    if dst then
        dst:close()
        return
    end
    local sources = {"../addons/mini_addons_p/log.dat", "../addons/mini_addons/log.dat"}
    for _, src_path in ipairs(sources) do
        local src = io.open(src_path, "r")
        if src then
            src:close()
            local ok = core_g.copy_file(src_path, dst_path)
            core_g.vlog("boss_rank: log 引き継ぎ %s -> %s (%s)", src_path, dst_path, tostring(ok))
            if ok then
                core_g.queue_message(g.lang == "Japanese" and
                    "{ol}{#00BFFF}[Nexus Addons P] Mini Addons: ボスレランキングの保存データを引き継ぎました" or
                    "{ol}{#00BFFF}[Nexus Addons P] Mini Addons: Carried over the saved boss raid ranking data")
            end
            return
        end
    end
    core_g.vlog("boss_rank: 引き継ぐ log.dat が無い")
end

function Mini_addons_get_weekly_boss_data_reserve(base_job_id, is_four_weeks)
    result_tbl = {}
    processed_job_ids = {}
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    rankListBox:SetUserValue("MODE_BASE_ID", base_job_id)
    rankListBox:SetUserValue("MODE_IS_4W", is_four_weeks)
    rankListBox:SetUserValue("B_IDX", 1)
    rankListBox:SetUserValue("C_IDX", 1)
    rankListBox:SetUserValue("W_IDX", 0)
    rankListBox:SetUserValue("SHOULD_SAVE", 0)
    local classtype_tab = GET_CHILD_RECURSIVELY(induninfo, "classtype_tab")
    classtype_tab:SelectTab(0)
    start_time = os.clock()
    local file_path = g.boss_rank_log_path
    local loaded_data = g.load_dat(file_path)
    if loaded_data then
        for _, record in ipairs(loaded_data) do
            local week_str = record[1]
            local job_id_str = record[2]
            local is_confirmed_str = record[7]
            if is_confirmed_str == "true" then
                processed_job_ids[week_str .. job_id_str] = true
            end
        end
    end
    local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
    induninfo_class_selector:SetEnable(0)
    local msg = g.lang == "Japanese" and
                    "データ取得を開始します{nl}フレームを閉じずに暫くお待ちください" or
                    "Starting data acquisition{nl}Please wait a moment without closing the frame"
    imcAddOn.BroadMsg("NOTICE_Dm_!", msg, 3.0)
    Mini_addons_get_weekly_boss_data(rankListBox)
    rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_data", 1.2)
end

function Mini_addons_get_weekly_boss_data(rankListBox)
    local mode_base_id = rankListBox:GetUserIValue("MODE_BASE_ID")
    local mode_is_4w = rankListBox:GetUserIValue("MODE_IS_4W")
    local b_idx = rankListBox:GetUserIValue("B_IDX")
    local c_idx = rankListBox:GetUserIValue("C_IDX")
    local w_idx = rankListBox:GetUserIValue("W_IDX")
    if w_idx == 0 and b_idx == 1 and c_idx == 1 then
        local induninfo = ui.GetFrame("induninfo")
        local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
        season_tab:SelectTab(0)
        rankListBox:SetUserValue("CURRENT_WEEK_NUM", WEEKLY_BOSS_RANK_WEEKNUM_NUMBER())
    end
    local current_week_num = rankListBox:GetUserIValue("CURRENT_WEEK_NUM")
    local target_base_jobids
    local is_all_classes_mode = false
    if mode_base_id == 0 or mode_base_id == 1 then
        target_base_jobids = base_jobids
        is_all_classes_mode = true
    else
        target_base_jobids = {mode_base_id}
    end
    local num_weeks = (mode_base_id == 1 or mode_is_4w == 1) and 4 or 1
    if w_idx >= num_weeks then
        local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
        if induninfo_class_selector:IsVisible() == 1 then
            local classList = GET_CHILD_RECURSIVELY(induninfo_class_selector, "classList")
            if classList then
                AUTO_CAST(classList)
                classList:SetScrollPos(0)
            end
            INDUNINFO_CLASS_SELECTOR_UI_CLOSE(induninfo_class_selector)
        end
        induninfo_class_selector:SetEnable(1)
        local end_time = os.clock()
        local elapsed_time = end_time - start_time
        local msg = g.lang == "Japanese" and
                        string.format("処理が完了しました。所要時間: %.2f 秒", elapsed_time) or
                        string.format("The process is complete. Time elapsed: %.2f seconds", elapsed_time)
        ui.SysMsg(msg)
        return 0
    end
    local current_base_jobid = target_base_jobids[b_idx]
    local job_list = GET_JOB_LIST(current_base_jobid)
    local job_cls = job_list[c_idx]
    local next_b_idx, next_c_idx, next_w_idx = b_idx, c_idx + 1, w_idx
    local should_save_flag = 0
    if next_c_idx > #job_list then
        next_c_idx = 1
        next_b_idx = b_idx + 1
        if is_all_classes_mode then
            should_save_flag = 1
        end
    end
    if next_b_idx > #target_base_jobids then
        next_b_idx = 1
        next_c_idx = 1
        next_w_idx = w_idx + 1
        if not is_all_classes_mode then
            should_save_flag = 1
        end
    end
    if job_cls then
        local job_cls_id = TryGetProp(job_cls, "ClassID", 0)
        local week_offset = (num_weeks == 4) and (3 - w_idx) or 0
        local week_num = current_week_num - week_offset
        local key_to_check = tostring(week_num) .. tostring(job_cls_id)
        if job_cls_id ~= 0 and not processed_job_ids[key_to_check] then
            local induninfo = ui.GetFrame("induninfo")
            local induninfo_class_selector = ui.GetFrame("induninfo_class_selector")
            ui.OpenFrame("induninfo_class_selector")
            local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
            season_tab:SelectTab(week_offset)
            local classtype_tab = GET_CHILD_RECURSIVELY(induninfo, "classtype_tab")
            for k = 1, #base_jobids do
                if base_jobids[k] == current_base_jobid then
                    classtype_tab:SelectTab(k - 1)
                    break
                end
            end
            INDUNINFO_CLASS_SELECTOR_FILL_CLASS(current_base_jobid)
            weekly_boss.RequestWeeklyBossRankingInfoList(week_num, job_cls_id)
            local classList = GET_CHILD_RECURSIVELY(induninfo_class_selector, "classList")
            AUTO_CAST(classList)
            local pos = 0
            if c_idx > 18 then
                pos = 180
            elseif c_idx > 12 then
                pos = 120
            elseif c_idx > 6 then
                pos = 60
            end
            classList:SetScrollPos(pos)
            for i = 1, #job_list do
                local list_job = GET_CHILD_RECURSIVELY(induninfo_class_selector, "list_job_" .. i)
                if list_job then
                    local icon = GET_CHILD(list_job, "icon_pic")
                    if icon then
                        AUTO_CAST(icon)
                        if i == c_idx then
                            icon:SetColorTone("FFFFFFFF")
                        else
                            icon:SetColorTone("FF444444")
                        end
                    end
                end
            end
            rankListBox:SetUserValue("JOB_ID", job_cls_id)
            rankListBox:SetUserValue("WEEK_NUM", week_num)
            rankListBox:SetUserValue("SHOULD_SAVE", should_save_flag)
            rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_damage", 0.2)
            processed_job_ids[key_to_check] = true
            rankListBox:SetUserValue("B_IDX", next_b_idx)
            rankListBox:SetUserValue("C_IDX", next_c_idx)
            rankListBox:SetUserValue("W_IDX", next_w_idx)
            rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_data")
            rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_data", 1.2)
            return 0
        end
    end
    rankListBox:SetUserValue("B_IDX", next_b_idx)
    rankListBox:SetUserValue("C_IDX", next_c_idx)
    rankListBox:SetUserValue("W_IDX", next_w_idx)
    rankListBox:StopUpdateScript("Mini_addons_get_weekly_boss_data")
    rankListBox:RunUpdateScript("Mini_addons_get_weekly_boss_data", 0)
    return 0
end

function Mini_addons_get_weekly_boss_damage(rankListBox)
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    local job_id = rankListBox:GetUserValue("JOB_ID")
    local week_num = tonumber(rankListBox:GetUserValue("WEEK_NUM"))
    if not job_id or not week_num then
        return 0
    end
    local current_week_num = tonumber(rankListBox:GetUserIValue("CURRENT_WEEK_NUM"))
    local is_confirmed = (week_num < current_week_num) and "true" or "false"
    for i = 1, 20 do
        local ctrlset = GET_CHILD(rankListBox, "CTRLSET_" .. i)
        if ctrlset then
            AUTO_CAST(ctrlset)
            local name_ctrl = GET_CHILD(ctrlset, "attr_name_text", "ui::CRichText")
            local name = name_ctrl:GetTextByKey("value")
            local damage = session.weeklyboss.GetRankInfoDamage(i - 1)
            damage = string.gsub(damage, ",", "")
            damage = tonumber(damage)
            local job_cls = GetClassByType("Job", tonumber(job_id))
            local job_name = dic.getTranslatedStr(job_cls.Name)
            local msg = g.lang == "Japanese" and job_name .. " データを取得しました" or job_name ..
                            " Data obtained"
            imcAddOn.BroadMsg("NOTICE_Dm_quest_complete", msg, 1.2)
            local result_data = {week_num, job_id, i, name, damage, job_name, is_confirmed}
            table.insert(result_tbl, result_data)
        else
            if i == 1 then
                local job_cls = GetClassByType("Job", tonumber(job_id))
                local job_name = dic.getTranslatedStr(job_cls.Name)
                local result_data = {week_num, job_id, i, "None", "0", job_name, is_confirmed}
                table.insert(result_tbl, result_data)
            end
            break
        end
    end
    if rankListBox:GetUserIValue("SHOULD_SAVE") == 1 then
        local base_id = tonumber(job_id) - (tonumber(job_id) % 1000) + 1
        local job_cls = GetClassByType("Job", tonumber(base_id))
        local job_name = dic.getTranslatedStr(job_cls.Name)
        local msg
        if Mini_addons_save_log() then
            msg = g.lang == "Japanese" and "[" .. week_num .. "] 週の " .. job_name ..
                      " クラスのデータを保存しました" or "Saved data for the [" .. week_num ..
                      "] week's " .. job_name .. " class"
        else
            msg = g.lang == "Japanese" and "{#FF6347}[" .. week_num .. "] 週の " .. job_name ..
                      " クラスのデータを保存できませんでした" or "{#FF6347}Could not save data for the [" ..
                      week_num .. "] week's " .. job_name .. " class"
        end
        ui.SysMsg(msg)
        rankListBox:SetUserValue("SHOULD_SAVE", 0)
    end
    return 0
end

function Mini_addons_rebuild_log_file(induninfo)
    local file_path = g.boss_rank_log_path
    local log_data = g.load_dat(file_path)
    if not log_data then
        return 0
    end
    local classtype_tab = GET_CHILD_RECURSIVELY(induninfo, "classtype_tab")
    AUTO_CAST(classtype_tab)
    local cls_index = classtype_tab:GetSelectItemIndex()
    local base_job = base_jobids[cls_index + 1]
    local week_num = session.weeklyboss.GetNowWeekNum()
    local season_tab = GET_CHILD_RECURSIVELY(induninfo, "season_tab")
    AUTO_CAST(season_tab)
    local season_index = season_tab:GetSelectItemIndex()
    local season = week_num - season_index
    local rebuilt_table = {}
    for _, record in ipairs(log_data) do
        local week_num_ = tonumber(record[1])
        local job_id = tonumber(record[2])
        local name = record[4]
        if week_num_ == season and (job_id > base_job and job_id < base_job + 1000) then
            if not rebuilt_table[name] then
                rebuilt_table[name] = {}
            end
            table.insert(rebuilt_table[name], job_id)
        end
    end
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    for i = 1, 20 do
        local ctrlset = GET_CHILD(rankListBox, "CTRLSET_" .. i)
        if ctrlset then
            AUTO_CAST(ctrlset)
            local attr_name_text = GET_CHILD(ctrlset, "attr_name_text")
            if attr_name_text then
                AUTO_CAST(attr_name_text)
                local raw_name = attr_name_text:GetText()
                local job_ids = rebuilt_table[raw_name]
                for j = 1, 3 do
                    local icon = GET_CHILD(ctrlset, "job_icon" .. j)
                    if icon then
                        icon:ShowWindow(0)
                    end
                end
                local nodata = GET_CHILD(ctrlset, "nodata_" .. i)
                if nodata then
                    nodata:ShowWindow(0)
                end
                if job_ids then
                    local rect = attr_name_text:GetMargin()
                    attr_name_text:SetMargin(rect.left, rect.top + 4, rect.right, rect.bottom)
                    for j = 1, 3 do
                        local job_id = job_ids[j]
                        if job_id then
                            local job_cls = GetClassByType("Job", job_id)
                            if job_cls then
                                local job_icon = ctrlset:CreateOrGetControl("picture", "job_icon" .. j,
                                    (attr_name_text:GetWidth() + ((j - 1) * 30)), 5, 30, 30)
                                AUTO_CAST(job_icon)
                                job_icon:SetImage(job_cls.Icon)
                                job_icon:SetEnableStretch(1)
                                job_icon:EnableHitTest(1)
                                ctrlset:EnableHitTest(1)
                                job_icon:SetTooltipType("adventure_book_job_info")
                                job_icon:SetTooltipArg(job_id, 0, 0)
                                job_icon:ShowWindow(1)
                            end
                        end
                    end
                else
                    local nodata = ctrlset:CreateOrGetControl("richtext", "nodata_" .. i, attr_name_text:GetWidth(), 10,
                        30, 30)
                    AUTO_CAST(nodata)
                    nodata:SetText("{#000000}No data")
                    nodata:ShowWindow(1)
                end
            end
        end
    end
    return 0
end

function Mini_addons_WEEKLY_BOSS_RANK_UPDATE()
    if g.settings.boss_rank == 0 then
        return
    end
    local induninfo = ui.GetFrame("induninfo")
    local rankListBox = GET_CHILD_RECURSIVELY(induninfo, "rankListBox")
    AUTO_CAST(rankListBox)
    if rankListBox:HaveUpdateScript("Mini_addons_get_weekly_boss_data") == false then
        Mini_addons_rebuild_log_file(induninfo)
    end
end
