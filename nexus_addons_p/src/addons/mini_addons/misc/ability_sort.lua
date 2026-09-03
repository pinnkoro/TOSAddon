-- 特性をスキル順に並べる(設定 ability_sort)
--
-- 素の SKILLABILITY_FILL_ABILITY_GB は特性の一覧を table.sort に通すが、その比較関数は
-- 「DEFAULT_ABIL を末尾へ回す」だけで、ActiveGroup を比べる行には到達しない
-- (両方が同じ真偽値なら先に false を返して抜ける)。結果は「クラス定義の順を不安定ソートに
-- 通したもの」で、左のスキル欄の並びとは無関係になる。
--
-- ここでは**素をそのまま呼んで行を作らせ、出来た行を SetPos で並べ直すだけ**にする
-- (素の関数を書き写さない: CLAUDE.md)。名前一覧のフックでは素の sort に通されて
-- 並びを制御できないので、行が出来た後に触る。
--
-- 並びの規則:
--   1. スキルに紐付かない特性(職業共通の強化など)   … 先頭
--   2. スキルに紐付く特性 … 対応するスキルの表示順。同じスキルの中は素の並びを保つ
--   3. DEFAULT_ABIL                                    … 末尾(素と同じ)
-- 特性とスキルの対応は特性クラスの SkillCategory(`;` 区切りのスキル名)。素の
-- GET_ABILITYLIST_BY_SKILL_NAME が同じ列を使っている。複数のスキルに紐付く特性は
-- 一番早いスキルの位置に置く。

-- 並びの決め方(純ロジック。docs/tests/test_ability_sort.lua が検査する)。
--   rows       … {{skills = {スキル名, ...}, is_default = bool, pos = 素の並び,
--                  active_group = ActiveGroup("None" なら単独)}, ...}
--   skill_rank … {[スキル名] = 表示順(小さいほど先)}
-- 戻り値は並べ替えた rows(要素はそのまま)。table.sort は安定ではないので、
-- 同じ順位の中は pos を最後の決め手にして素の並びを保つ。
--
-- **同じ ActiveGroup の特性は必ず隣り合わせにする。** 素の
-- SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP は「隣接する連なり」単位で括弧枠を描き、
-- 分断されると同名のコントロールを 2 回作るうえ、区間の要素数が 1 になって中央の
-- ON 画像が出なくなる。同じ ActiveGroup でも紐付くスキルが違う組(Desperado22/23、
-- Thaumaturge22/23、Schwarzereiter31/34 など)があるので、ActiveGroup ごとに
-- 「一番早いスキルの順位」と「一番早い素の並び」を共有させて、まとまりを崩さない。
function Mini_addons_ability_sort_order(rows, skill_rank)
    local function has_group(row)
        return row.active_group ~= nil and row.active_group ~= "None" and not row.is_default
    end
    -- ActiveGroup ごとの代表値(一番早いスキル順位 / 一番早い素の並び)
    local group_rank = {}
    local group_pos = {}
    for i, row in ipairs(rows) do
        local rank = nil
        for _, skill in ipairs(row.skills or {}) do
            local r = skill_rank[skill]
            if r ~= nil and (rank == nil or r < rank) then
                rank = r
            end
        end
        row._rank = rank
        if has_group(row) then
            local key = row.active_group
            if rank ~= nil and (group_rank[key] == nil or rank < group_rank[key]) then
                group_rank[key] = rank
            end
            local pos = row.pos or i
            if group_pos[key] == nil or pos < group_pos[key] then
                group_pos[key] = pos
            end
        end
    end
    local keyed = {}
    for i, row in ipairs(rows) do
        local rank = row._rank
        local pos = row.pos or i
        local head = pos
        if has_group(row) then
            rank = group_rank[row.active_group]
            head = group_pos[row.active_group]
        end
        row._rank = nil
        local group
        if row.is_default then
            group = 3
        elseif rank == nil then
            group = 1
        else
            group = 2
        end
        keyed[#keyed + 1] = {row = row, group = group, rank = rank or 0, head = head, pos = pos}
    end
    table.sort(keyed, function(a, b)
        if a.group ~= b.group then
            return a.group < b.group
        end
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        if a.head ~= b.head then
            return a.head < b.head
        end
        return a.pos < b.pos
    end)
    local out = {}
    for i, k in ipairs(keyed) do
        out[i] = k.row
    end
    return out
end

-- SkillCategory("A;B;C" / "None" / nil)をスキル名の配列にする
function Mini_addons_ability_sort_split_skills(category)
    local skills = {}
    if type(category) ~= "string" or category == "" or category == "None" then
        return skills
    end
    for name in string.gmatch(category, "[^;]+") do
        skills[#skills + 1] = name
    end
    return skills
end

-- スキル欄の表示順を {[スキル名] = 順位} で返す。
-- 順位は**画面に並んだ位置(Y, X)**から取る。素のスキル欄は解放レベルごとに段を組む際
-- pairs で回しており(SKILLABILITY_DEPLOY_JOB_SKILL)、クラス定義から同じ順を再現するより
-- 出来上がった画面を読むほうが確実なため。行が見つからないスキルがあれば、
-- 解放レベル → SkillTree の添字の順へ落とす。
local function ability_sort_skill_rank(skillability_job, jobClsName)
    local skill_gb = GET_CHILD(skillability_job, "skill_gb")
    local skilltree_gb = skill_gb and GET_CHILD_RECURSIVELY(skill_gb, "skilltree_gb")
    local clslist = GetClassList("SkillTree")
    local entries = {}
    local all_found = skilltree_gb ~= nil
    local index = 1
    while true do
        local cls = GetClassByNameFromList(clslist, jobClsName .. "_" .. index)
        if cls == nil then
            break
        end
        local skill_name = cls.SkillName
        local ctrl = skilltree_gb and GET_CHILD_RECURSIVELY(skilltree_gb, "SKILL_" .. skill_name)
        if ctrl == nil then
            all_found = false
        end
        entries[#entries + 1] = {
            name = skill_name,
            y = ctrl and ctrl:GetY() or 0,
            x = ctrl and ctrl:GetX() or 0,
            unlock = tonumber(TryGetProp(cls, "UnlockClassLevel", 0)) or 0,
            index = index
        }
        index = index + 1
    end
    table.sort(entries, function(a, b)
        if all_found then
            if a.y ~= b.y then
                return a.y < b.y
            end
            if a.x ~= b.x then
                return a.x < b.x
            end
        elseif a.unlock ~= b.unlock then
            return a.unlock < b.unlock
        end
        return a.index < b.index
    end)
    local rank = {}
    for i, entry in ipairs(entries) do
        rank[entry.name] = i
    end
    return rank, #entries, all_found
end

local ABILITY_ROW_PREFIX = "skillability_ability_"

-- 素の括弧枠の描き直し。pcall に直接渡さず関数で包むのは、docs/vanilla_api.py が
-- 「素の API を直接呼んでいる箇所」だけを拾うため(値として渡すと一覧から消える)
local function ability_sort_make_group(abilitylist_gb, cls_list, height)
    SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP(abilitylist_gb, cls_list, height)
end

-- 置換方式フック。素を呼んで行を作らせた後、並べ直す。
-- Common(アカウント特性)タブは素が別の関数で組むので触らない。
function Mini_addons_SKILLABILITY_FILL_ABILITY_GB(skillability_job, ability_gb, jobClsName)
    local origin = g.FUNCS["SKILLABILITY_FILL_ABILITY_GB"]
    if origin then
        origin(skillability_job, ability_gb, jobClsName)
    end
    if g.settings.ability_sort ~= 1 or jobClsName == "Common" then
        return
    end
    local ok, err = pcall(Mini_addons_ability_sort_apply, skillability_job, ability_gb, jobClsName)
    if not ok then
        -- 行を動かす前に失敗すれば素の並びのまま。動かした後の失敗は apply 側で行を戻す。
        -- どちらでも素の描画は残るので、機能を巻き込んで落とさない
        core_g.vlog("{#FF6347}mini_addons: 特性の並べ替えに失敗 job=%s: %s{/}", tostring(jobClsName),
            tostring(err))
    end
end

function Mini_addons_ability_sort_apply(skillability_job, ability_gb, jobClsName)
    local abilitylist_gb = GET_CHILD(ability_gb, "abilitylist_gb")
    if abilitylist_gb == nil then
        core_g.vlog("mini_addons: 特性の並べ替え: abilitylist_gb が無い job=%s", tostring(jobClsName))
        return
    end
    AUTO_CAST(abilitylist_gb)
    local height = ui.GetControlSetAttribute("skillability_ability", "height")
    local skill_rank, skill_count, from_screen = ability_sort_skill_rank(skillability_job, jobClsName)

    -- 素が作った行を集める。名前は skillability_ability_<特性のクラス名>
    local rows = {}
    local prefix_len = string.len(ABILITY_ROW_PREFIX)
    local child_count = abilitylist_gb:GetChildCount()
    for i = 0, child_count - 1 do
        local child = abilitylist_gb:GetChildByIndex(i)
        local name = child:GetName()
        if string.sub(name, 1, prefix_len) == ABILITY_ROW_PREFIX then
            local abil_name = string.sub(name, prefix_len + 1)
            local abil_cls = GetClass("Ability", abil_name)
            if abil_cls ~= nil then
                AUTO_CAST(child)
                rows[#rows + 1] = {
                    ctrl = child,
                    cls = abil_cls,
                    skills = Mini_addons_ability_sort_split_skills(TryGetProp(abil_cls, "SkillCategory", "None")),
                    is_default = IS_ABILITY_KEYWORD(abil_cls, "DEFAULT_ABIL"),
                    active_group = TryGetProp(abil_cls, "ActiveGroup", "None"),
                    pos = child:GetY()
                }
            end
        end
    end
    if #rows == 0 then
        core_g.vlog("mini_addons: 特性の並べ替え: 行が無い job=%s", tostring(jobClsName))
        return
    end

    -- 括弧枠を描き直す素の関数が無ければ、行を動かす前に諦める(IMC 側のパッチで
    -- 消える・名前が変わるのは構文チェックを通り抜けて実機でだけ分かる。消してから
    -- 描き直しに失敗すると枠が無いまま残るので、触る前に確かめる)
    if type(_G["SKILLABILITY_MAKE_GROUP_BY_ACTIVE_GROUP"]) ~= "function" or
        type(_G["DESTROY_CHILD_BYNAME"]) ~= "function" then
        core_g.vlog("{#FF6347}mini_addons: 特性の並べ替え: 素の括弧枠の関数が無いので触らない job=%s{/}",
            tostring(jobClsName))
        return
    end

    local sorted = Mini_addons_ability_sort_order(rows, skill_rank)
    local cls_list = {}
    local names = {}
    for i, row in ipairs(sorted) do
        row.ctrl:SetPos(row.ctrl:GetX(), (i - 1) * height)
        cls_list[i] = row.cls
        names[i] = row.cls.ClassName
    end

    -- ActiveGroup の括弧枠と中央のアイコンは行の位置に合わせて素が描いているので、
    -- 消してから素の関数に新しい順で描き直させる(center_active_group_* も同じ
    -- 前方一致で消える)。描き直しに失敗したら行を素の位置へ戻し、素の順で枠も
    -- 描き直しておく(枠まで戻せなくても、行だけ入れ替わった中途半端な姿は残さない)
    DESTROY_CHILD_BYNAME(abilitylist_gb, "active_group_")
    local ok, err = pcall(ability_sort_make_group, abilitylist_gb, cls_list, height)
    if not ok then
        table.sort(rows, function(a, b) return a.pos < b.pos end)
        local origin_cls = {}
        for i, row in ipairs(rows) do
            row.ctrl:SetPos(row.ctrl:GetX(), row.pos)
            origin_cls[i] = row.cls
        end
        DESTROY_CHILD_BYNAME(abilitylist_gb, "active_group_")
        pcall(ability_sort_make_group, abilitylist_gb, origin_cls, height)
        error("括弧枠の描き直しに失敗したので行を素の並びへ戻した: " .. tostring(err), 0)
    end

    core_g.vlog("mini_addons: 特性を並べ替え job=%s 行=%d スキル=%d(%s) 順=%s", tostring(jobClsName), #rows,
        skill_count, from_screen and "画面の位置" or "解放Lv/添字", table.concat(names, ","))
end
