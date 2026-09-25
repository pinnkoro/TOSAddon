-- muteki ここから
g.muteki_trans_tbl = {
    etc = {
        buff_time = '{#000000}Hide until Buff duration (sec){/}',
        position_mode = '{#000000}Toggle Mode{/}',
        mode_desc = "{ol}ON: Follow Mode{nl}OFF: Fixed Mode",
        frame_lock = '{#000000}Frame Lock{/}',
        layer_lv = '{#000000}Layer Level{/}',
        layer_notice = 'MUTEKI Changed frame layer to %d',
        icon_mode = '{#000000}Display in icon mode{/}',
        color_tone = '{#FFFFFF}{ol}Current Color{/}',
        hide_sec = 'MUTEKI Hide gauge with remaining time more than %d seconds',
        not_notify = "{#000000}Hidden for this character{/}",
        pt_chat = "{#000000}Notify buffs via PT chat{/}",
        function_notice = "{#FFFFFF}{ol}Register by leftclick on the buff slot{nl}in the upper left corner of the screen{/}",
        icon_rotate = "{#000000}Rotate icon{/}",
        with_effect = "{#000000}With effect{/}",
        effect_setting = "{ol}Effect",
        effect_setting_notice = "{#FFFFFF}{ol}Choose the effect to play{/}",
        effect_title = "Effect Settings",
        effect_start = "{#000000}When the buff starts{/}",
        effect_over = "{#000000}When stacks reach the max{/}",
        effect_choose = "{ol}Pick from the list",
        effect_name = "{#000000}Effect name{/}",
        effect_name_notice = "{#FFFFFF}{ol}Type an effect name and press Enter{nl}Nothing is played if the client has no such effect{nl}Leave it empty to play nothing{/}",
        effect_scale_notice = "{#FFFFFF}{ol}Size of the effect (1.0 = its own size){nl}Enter a number and press Enter. The previous default is 6.0{/}",
        effect_use_notice = "{#FFFFFF}{ol}Turn this effect on or off{nl}\"When the buff starts\" is the same setting as \"With effect\" on the settings screen{nl}Test still plays it even when it is off{/}",
        effect_type_actor = "{ol}Normal effect",
        effect_type_ui = "{ol}UI effect",
        effect_force = "{#000000}Raise the transparency while it plays{/}",
        effect_force_notice = "{#FFFFFF}{ol}Restores the \"My effect transparency\" system option to full{nl}while the effect plays, then puts it back{nl}Your other effects also show at full during that time (about 1.5 seconds){/}",
        effect_test = "{ol}Test",
        effect_test_notice = "{#FFFFFF}{ol}Play the current effect right here{/}",
        effect_set = "MUTEKI Effect set to %s",
        nico_chat = "{#000000}Nico Chat Display{/}",
        delete_notice = "{#FFFFFF}{ol}Right-click the icon to unregister{/}",
        color_notice = "{#FFFFFF}{ol}The first two characters are for shade/density (AA = Light - FF = Dark)" ..
            "{nl}The following six characters are the hexadecimal color code.{/}",
        count_display = "{#000000}Display Buff Stacks{/}",
        end_sound = "{#000000}Buff End Sound{/}",
        add_check = 'Add %s to MUTEKI?',
        add_buff = 'MUTEKI Added %s in settings',
        delete_buff = 'MUTEKI Removed %s in settings',
        add_new = '{#FFFFFF}{ol}Add Buff',
        add_buffid = "{#FFFFFF}{ol}Add by Buff ID{/}",
        lock_notice = "{#FFFFFF}{ol}Follow Mode is always locked",
        debuff_time = "{#000000}Manual DeBuff Duration",
        debuff_notice = "{#FFFFFF}{ol}Adjustment is required{nl}based on each character's skill level",
        debuff_manage_set = "{#FFFFFF}{ol}Set duration to %s seconds",
        auto_time = "{#FFFFFF}{ol}Turning ON automatically retrieves the debuff duration{nl}Note: This may not work correctly with some debuffs{nl}In that case, please turn it OFF and enter the value manually",
        buff_time_cid = "{#000000}Manual Buff Duration",
        buff_notice_cid = "{#FFFFFF}{ol}Manually input the duration for some buffs, such as magic circles{nl}whose time cannot be automatically retrieved{nl}Note: Values may vary depending on skill level and other factors",
        skill_text = "{#000000}Skill ID",
        skill_notice = "{#FFFFFF}{ol}If the duration is entered{nl}linking a buff to a skill enables time measurement",
        skill_set = "{#FFFFFF}{ol}Linked to %s skill",
        add_new_skill = '{#FFFFFF}{ol}Add Skill'
    },
    Japanese = {
        buff_time = '{#000000}指定されたバフの残り時間まで非表示(秒){/}',
        position_mode = '{#000000}モード切替{/}',
        mode_desc = "{ol}ON: 追従モード{nl}OFF: 固定モード",
        frame_lock = '{#000000}フレームロック{/}',
        layer_lv = '{#000000}レイヤーレベル{/}',
        layer_notice = 'MUTEKI フレームレイヤーを %d に変更しました',
        icon_mode = '{#000000}アイコンモードで表示{/}',
        color_tone = '{#FFFFFF}{ol}現在の色{/}',
        hide_sec = 'MUTEKI %d 秒以上のバフは非表示になります',
        not_notify = "{#000000}このキャラクターでは非表示{/}",
        pt_chat = "{#000000}バフをPTチャットでお知らせ{/}",
        function_notice = "{#FFFFFF}{ol}画面左上バフスロットを{nl}左クリックでも登録出来ます{/}",
        icon_rotate = "{#000000}アイコン回転{/}",
        with_effect = "{#000000}エフェクト付与{/}",
        effect_setting = "{ol}エフェクト",
        effect_setting_notice = "{#FFFFFF}{ol}出すエフェクトを選びます{/}",
        effect_title = "エフェクト設定",
        effect_start = "{#000000}バフ開始時{/}",
        effect_over = "{#000000}重複が最大になったとき{/}",
        effect_choose = "{ol}一覧から選ぶ",
        effect_name = "{#000000}エフェクト名{/}",
        effect_name_notice = "{#FFFFFF}{ol}エフェクト名を入れて Enter{nl}クライアントに無い名前を入れても何も出ません{nl}空にすると何も出しません{/}",
        effect_scale_notice = "{#FFFFFF}{ol}エフェクトの大きさ（1.0 で素の大きさ）{nl}数字を入れて Enter。従来の既定は 6.0{/}",
        effect_use_notice = "{#FFFFFF}{ol}このエフェクトを出すかどうか{nl}「バフ開始時」は設定画面の「エフェクト付与」と同じ設定です{nl}OFF でも試し再生は出ます{/}",
        effect_type_actor = "{ol}通常エフェクト",
        effect_type_ui = "{ol}UIエフェクト",
        effect_force = "{#000000}エフェクト中は透明度を自動で上げる{/}",
        effect_force_notice = "{#FFFFFF}{ol}出している間だけ、システム設定の「自分のエフェクト透明度」を{nl}最大に戻して、そのあと元の値へ戻します{nl}その間（約1.5秒）は自分の他のエフェクトも濃く見えます{/}",
        effect_test = "{ol}試し再生",
        effect_test_notice = "{#FFFFFF}{ol}今の設定のエフェクトをその場で再生します{/}",
        effect_set = "MUTEKI エフェクトを %s にしました",
        nico_chat = "{#000000}ニコチャット表示{/}",
        delete_notice = "{#FFFFFF}{ol}アイコン右クリックで登録解除します{/}",
        color_notice = "{#FFFFFF}{ol}先頭2文字は濃淡 (AA=薄い～FF=濃い)" ..
            "{nl}続く6文字は16進数のカラーコード{/}",
        count_display = "{#000000}バフ重複を表示{/}",
        end_sound = "{#000000}バフ終了時に音でお知らせ{/}",
        add_check = 'MUTEKIに%sを追加しますか？',
        add_buff = 'MUTEKIに%sを追加しました.',
        delete_buff = "MUTEKIから %s を削除しました.",
        add_new = '{#FFFFFF}{ol}バフ追加',
        add_buffid = "{#FFFFFF}{ol}バフIDで直接追加{/}",
        lock_notice = "{#FFFFFF}{ol}追従モードでは常にロックされます",
        debuff_time = "{#000000}デバフ継続時間を入力",
        debuff_notice = "{#FFFFFF}{ol}キャラクター毎のスキルレベルなどで調整必要です",
        debuff_manage_set = "{#FFFFFF}{ol}継続時間を %s 秒で設定しました",
        auto_time = "{#FFFFFF}{ol}ONにするとデバフ継続時間を自動取得します{nl}一部のデバフでは機能しない場合があります{nl}その際はOFFにして手動で入力してください",
        buff_time_cid = "{#000000}バフ継続時間を手動入力",
        buff_notice_cid = "{#FFFFFF}{ol}魔法陣など一部の時間取得出来ないバフの継続時間を手動入力します{nl}値はスキルレベルなどで異なる場合があります",
        skill_text = "{#000000}スキルID",
        skill_notice = "{#FFFFFF}{ol}継続時間を入力した場合{nl}バフとスキルを紐づけることで時間計測が可能になります",
        skill_set = "{#FFFFFF}{ol}%s スキルと紐づけました",
        add_new_skill = '{#FFFFFF}{ol}スキル追加'
    },
    kr = {
        buff_time = "{#000000}지정된 버프 잔여 시간까지 숨기기 (초){/}",
        position_mode = "{#000000}모드 전환{/}",
        mode_desc = "{ol}ON: 추종 모드{nl}OFF: 고정 모드",
        frame_lock = "{#000000}프레임 잠금{/}",
        layer_lv = "{#000000}레이어 레벨{/}",
        layer_notice = 'MUTEKI 프레임 레이어를 %d 로 변경했습니다',
        icon_mode = "{#000000}아이콘 모드로 표시{/}",
        color_tone = "{#FFFFFF}{ol}현재 색상{/}",
        hide_sec = "MUTEKI - %d초 이상 남은 버프는 표시하지 않습니다.",
        not_notify = "{#000000}이 캐릭터에서는 숨김{/}",
        pt_chat = "{#000000}PT 채팅으로 버프를 알려드립니다{/}",
        function_notice = "{#FFFFFF}{ol}화면 왼쪽 상단의 버프 슬롯을{nl}왼쪽 클릭으로도 등록할 수 있습니다{/}",
        icon_rotate = "{#000000}아이콘 회전{/}",
        with_effect = "{#000000}효과 적용{/}",
        effect_setting = "{ol}효과",
        effect_setting_notice = "{#FFFFFF}{ol}재생할 효과를 선택합니다{/}",
        effect_title = "효과 설정",
        effect_start = "{#000000}버프 시작 시{/}",
        effect_over = "{#000000}중첩이 최대가 되었을 때{/}",
        effect_choose = "{ol}목록에서 선택",
        effect_name = "{#000000}효과 이름{/}",
        effect_name_notice = "{#FFFFFF}{ol}효과 이름을 입력하고 Enter{nl}클라이언트에 없는 이름은 아무것도 재생되지 않습니다{nl}비워 두면 아무것도 재생하지 않습니다{/}",
        effect_scale_notice = "{#FFFFFF}{ol}효과의 크기 (1.0 = 원래 크기){nl}숫자를 입력하고 Enter. 기존 기본값은 6.0{/}",
        effect_use_notice = "{#FFFFFF}{ol}이 효과를 표시할지 여부{nl}\"버프 시작 시\"는 설정 화면의 \"효과 적용\"과 같은 설정입니다{nl}꺼져 있어도 시험 재생은 표시됩니다{/}",
        effect_type_actor = "{ol}일반 효과",
        effect_type_ui = "{ol}UI 효과",
        effect_force = "{#000000}효과 중에는 투명도를 자동으로 올린다{/}",
        effect_force_notice = "{#FFFFFF}{ol}효과가 나오는 동안만 시스템 설정의 \"내 효과 투명도\"를{nl}최대로 되돌리고, 그 후 원래 값으로 되돌립니다{nl}그동안(약 1.5초)은 자신의 다른 효과도 진하게 보입니다{/}",
        effect_test = "{ol}시험 재생",
        effect_test_notice = "{#FFFFFF}{ol}현재 설정된 효과를 바로 재생합니다{/}",
        effect_set = "MUTEKI 효과를 %s 로 설정했습니다",
        nico_chat = "{#000000}니코 채팅 표시{/}",
        delete_notice = "{#FFFFFF}{ol}아이콘을 마우스 오른쪽 버튼으로 클릭하여 등록 해제{/}",
        color_notice = "{#FFFFFF}{ol}앞의 두 문자는 농도를 나타냅니다 (AA = 옅음 - FF = 진함)" ..
            "{nl}이어지는 6개의 문자는 16진수 컬러 코드입니다{/}",
        count_display = "{#000000}버프 중첩 표시{/}",
        end_sound = "{#000000}버프 종료 시 소리로 알림{/}",
        add_check = 'MUTEKI - 에 %s를 추가하시겠습니까?',
        add_buff = "MUTEKI - %s 버프를 추가했습니다",
        delete_buff = "MUTEKI - %s 버프를 삭제했습니다",
        add_new = '{#FFFFFF}{ol}버프 추가',
        add_buffid = "{#FFFFFF}{ol}버프ID로 직접 추가{/}",
        lock_notice = "{#FFFFFF}{ol}추종 모드에서는 항상 잠금됩니다",
        debuff_time = "{#000000}디버프 지속 시간 입력",
        debuff_notice = "{#FFFFFF}{ol}캐릭터별 스킬 레벨에 따라 조정이 필요합니다",
        debuff_manage_set = "{#FFFFFF}{ol}지속 시간을 %s 초로 설정했습니다",
        auto_time = "{#FFFFFF}{ol}ON으로 설정 시 디버프 지속 시간을 자동으로 가져옵니다{nl}주의: 일부 디버프에서는 제대로 작동하지 않을 수 있습니다{nl}그럴 경우, 해당 기능을 OFF로 끄고 수동으로 입력해 주십시오",
        buff_time_cid = "{#000000}버프 지속 시간 수동 입력",
        buff_notice_cid = "{#FFFFFF}{ol}마법진 등 일부 시간 획득이 불가능한 버프의 지속 시간을 수동으로 입력합니다{nl}참고: 값은 스킬 레벨 등에 따라 달라질 수 있습니다",
        skill_text = "{#000000}스킬 ID",
        skill_notice = "{#FFFFFF}{ol}지속 시간을 입력한 경우{nl}버프와 스킬을 연동하면 시간 측정이 가능해집니다",
        skill_set = "{#FFFFFF}{ol}%s 스킬과 연동했습니다",
        add_new_skill = '{#FFFFFF}{ol}스킬 추가'
    }
}

-- 出せるエフェクトの候補。Lua からエフェクト名を列挙する手立ては無いので、よく使いそうな
-- ものだけをここに並べ、一覧に無い名前は設定画面の入力欄から直接指定する。
-- 名前はクライアント（effect.ipf の forkparticle）に実在するものだけを載せている。
-- 表示名は「そのエフェクトが素のどこで使われているか」で、見た目は試し再生で確かめる。
-- ui = true のものは UI に描くエフェクト（PlayUIEffect）で、ワールドのエフェクトとは名前の
-- プールも大きさの単位も別。scale はそのエフェクトの目安の大きさ（選ぶと入る）。
g.MUTEKI_EFFECT_PRESETS = {{name = "None", ja = "エフェクトなし", etc = "No effect"},
                           {name = "F_sys_TPBOX_great_300", ja = "従来のエフェクト", etc = "Previous default",
                            scale = 6.0},
                           {name = "F_pc_level_up", ja = "レベルアップ", etc = "Level up", scale = 1.5},
                           {name = "F_pc_joblevel_up", ja = "クラスレベルアップ", etc = "Class level up",
                            scale = 1.5},
                           {name = "F_pc_StatPoint_up", ja = "ステータス上昇", etc = "Stat point up", scale = 1.5},
                           {name = "F_pc_class_change", ja = "クラスチェンジ", etc = "Class change", scale = 1.5},
                           {name = "F_sys_expcard_great", ja = "経験値カード(大)", etc = "EXP card (great)",
                            scale = 1.5},
                           {name = "F_sys_expcard_good", ja = "経験値カード(中)", etc = "EXP card (good)",
                            scale = 1.5},
                           {name = "F_pattern025_loop", ja = "紋章", etc = "Pattern", scale = 1.5},
                           {name = "F_buff_Cleric_Bless_Buff", ja = "ブレス", etc = "Bless", scale = 1.5},
                           {name = "F_buff_Cleric_Heal_Buff", ja = "ヒール", etc = "Heal", scale = 1.5},
                           {name = "F_buff_Cleric_Haste_Buff", ja = "ヘイスト", etc = "Haste", scale = 1.5},
                           {name = "F_pc_warp_light", ja = "ワープの光", etc = "Warp light", scale = 1.5},
                           {name = "F_sys_heart", ja = "ハート", etc = "Heart", scale = 1.5},
                           {name = "F_sys_like", ja = "いいね", etc = "Like", scale = 1.5},
                           {name = "F_circle016_rainbow", ja = "虹色の円", etc = "Rainbow circle", scale = 1.5},
                           {name = "UI_success002", ja = "成功", etc = "Success", ui = true, scale = 12},
                           {name = "UI_success_charge", ja = "チャージ完了", etc = "Charge complete", ui = true,
                            scale = 12},
                           {name = "I_sys_fullcharge", ja = "フルチャージ", etc = "Full charge", ui = true,
                            scale = 12},
                           {name = "SYS_quest_mark", ja = "クエストの印", etc = "Quest mark", ui = true, scale = 12},
                           {name = "SYS_quest_mark_blue", ja = "クエストの印(青)", etc = "Quest mark (blue)",
                            ui = true, scale = 12}}

-- 名前から候補表の行を引く。直接入力された名前は表に無いので nil が返る。
function Muteki_effect_preset(effect_name)
    for _, preset in ipairs(g.MUTEKI_EFFECT_PRESETS) do
        if preset.name == effect_name then
            return preset
        end
    end
    return nil
end

-- 既定のエフェクト名と大きさ。**何も設定していないときの見え方は従来のまま**にする
-- （開始時は F_sys_TPBOX_great_300 を scale 6.0、重複が最大のときは F_pattern025_loop を
-- scale 1.5 で出していた）。なお F_sys_TPBOX_great_300 は muteki2ex 由来の名前で、
-- 手元のクライアント（effect.ipf のエントリ名 / effectlist.xml）には見当たらない。
-- PlayActorEffect は解決できない名前を渡されても黙って何も出さないので、
-- 何も出ないときは一覧から別のエフェクトへ変えられるようにしてある。
g.MUTEKI_DEFAULT_EFFECT = "F_sys_TPBOX_great_300"
g.MUTEKI_DEFAULT_OVER_EFFECT = "F_pattern025_loop"
g.MUTEKI_DEFAULT_SCALE = 6.0
g.MUTEKI_DEFAULT_OVER_SCALE = 1.5
-- UI エフェクトは名前のプールも大きさの単位も別なので、既定も別に持つ
g.MUTEKI_DEFAULT_UI_EFFECT = "UI_success002"
g.MUTEKI_DEFAULT_UI_SCALE = 12
g.MUTEKI_EFFECT_LIFETIME = 1.0
-- UI エフェクトを出しておく秒数。**素の PlayUIEffect には「何秒で終わる」という指定が無く、
-- ループ指定のエフェクト（名前に _loop が付くものなど）は止めるまで出っぱなしになる。**
-- 素も同じで、アドオンごとに決め打ちの秒数で StopUIEffect を呼んでいる
-- （例: aether_gem_reinforce の SUCCESS_EFFECT_DURATION）。ここも同じやり方で止める。
-- 2.0 秒なのは、候補に載せた UI エフェクトの 1 周がどれも 2.0 秒以内だから
-- （effectlist.xml の duration + startdelay。成功 2.0 / チャージ完了 2.0 /
--  フルチャージ 1.2 / クエストの印 0.1）。短くすると途中で切れる。
g.MUTEKI_UI_EFFECT_TIME = 2.0

-- エフェクトの種類。2 つある。
--   "actor" … 通常エフェクト。キャラに出す（システム設定の「自分のエフェクト透明度」に従う）
--   "ui"    … UI エフェクト。Muteki の枠の上に描く（透明度の設定とは無関係）
-- **名前のプールが別**なので、設定も種類ごとに分けて憶える（Muteki_effect_keys）。
-- 以前の版には "force"（キャラに出して透明度を上げる）という 3 つ目があった。
-- その値は「通常エフェクト + 透明度を自動で上げる」として読み替える。
function Muteki_effect_mode(buff_data, kind)
    local mode
    if kind == "over" then
        mode = buff_data and buff_data.over_effect_mode
    else
        mode = buff_data and buff_data.effect_mode
    end
    if mode == "ui" then
        return "ui"
    end
    return "actor"
end

-- 設定のキー名（名前 / 大きさ）。**種類ごとに別々に持つ。**
-- 種類を切り替えても、それぞれで選んだ名前と大きさがそのまま残るようにするため。
function Muteki_effect_keys(kind, mode)
    local prefix = (kind == "over") and "over_effect" or "effect"
    if mode == "ui" then
        return prefix .. "_ui_name", prefix .. "_ui_scale"
    end
    return prefix .. "_name", prefix .. "_scale"
end

function Muteki_effect_default_name(kind, is_ui)
    if is_ui then
        return g.MUTEKI_DEFAULT_UI_EFFECT
    elseif kind == "over" then
        return g.MUTEKI_DEFAULT_OVER_EFFECT
    end
    return g.MUTEKI_DEFAULT_EFFECT
end

function Muteki_effect_default_scale(kind, is_ui)
    if is_ui then
        return g.MUTEKI_DEFAULT_UI_SCALE
    elseif kind == "over" then
        return g.MUTEKI_DEFAULT_OVER_SCALE
    end
    return g.MUTEKI_DEFAULT_SCALE
end

-- 今の種類でのエフェクト名。昔の設定 JSON には無いキーなので、未設定なら既定を返す。
function Muteki_effect_name(buff_data, kind)
    local mode = Muteki_effect_mode(buff_data, kind)
    local name_key = Muteki_effect_keys(kind, mode)
    local effect_name = buff_data and buff_data[name_key]
    if effect_name and effect_name ~= "" then
        return effect_name
    end
    return Muteki_effect_default_name(kind, mode == "ui")
end

-- 今の種類での大きさ。1.0 が素の大きさ（UI エフェクトは 12 前後が目安）。
function Muteki_effect_scale(buff_data, kind)
    local mode = Muteki_effect_mode(buff_data, kind)
    local _, scale_key = Muteki_effect_keys(kind, mode)
    local scale = buff_data and tonumber(buff_data[scale_key])
    if scale then
        return scale
    end
    return Muteki_effect_default_scale(kind, mode == "ui")
end

function Muteki_effect_name_set(buff_data, kind, effect_name)
    local name_key = Muteki_effect_keys(kind, Muteki_effect_mode(buff_data, kind))
    buff_data[name_key] = effect_name
end

function Muteki_effect_scale_set(buff_data, kind, scale)
    local _, scale_key = Muteki_effect_keys(kind, Muteki_effect_mode(buff_data, kind))
    buff_data[scale_key] = scale
end

-- エフェクトを出している間だけ「自分のエフェクト透明度」を上げるか。
-- 通常エフェクトのときだけ意味がある（UI エフェクトは透明度の設定を受けない）。
function Muteki_effect_force(buff_data, kind)
    local raw, mode
    if kind == "over" then
        raw = buff_data and buff_data.over_effect_force
        mode = buff_data and buff_data.over_effect_mode
    else
        raw = buff_data and buff_data.effect_force
        mode = buff_data and buff_data.effect_mode
    end
    if raw ~= nil then
        return raw ~= 0
    end
    return mode == "force" -- 以前の版の値を読み替える
end

function Muteki_effect_force_set(buff_data, kind, checked)
    if kind == "over" then
        buff_data.over_effect_force = checked
    else
        buff_data.effect_force = checked
    end
end

-- そのエフェクトを出すかどうか。
--   開始時 … 設定画面の「エフェクト付与」と同じ値（effect_check）。既定は OFF
--   重複が最大 … over_effect_check。**未設定は ON**（従来は必ず出ていたので、そこに合わせる）
function Muteki_effect_enabled(buff_data, kind)
    if kind == "over" then
        return ((buff_data and buff_data.over_effect_check) or 1) ~= 0
    end
    return (buff_data and buff_data.effect_check) == 1
end

function Muteki_effect_enabled_set(buff_data, kind, checked)
    if kind == "over" then
        buff_data.over_effect_check = checked
    else
        buff_data.effect_check = checked
    end
end

function Muteki_effect_mode_set(buff_data, kind, mode)
    if kind == "over" then
        buff_data.over_effect_mode = mode
    else
        buff_data.effect_mode = mode
    end
end

-- そのバフの設定どおりにエフェクトを出す。
function Muteki_effect_fire(buff_data, kind)
    local effect_name = Muteki_effect_name(buff_data, kind)
    local scale = Muteki_effect_scale(buff_data, kind)
    if Muteki_effect_mode(buff_data, kind) == "ui" then
        Muteki_effect_play_ui(effect_name, scale)
    else
        Muteki_effect_play(effect_name, scale, Muteki_effect_force(buff_data, kind))
    end
end

-- 自キャラにエフェクトを出す。"None" と空文字は「出さない」。
function Muteki_effect_play(effect_name, scale, force)
    if not effect_name or effect_name == "" or effect_name == "None" then
        g.vlog("muteki: エフェクトは出さない指定 name=%s", tostring(effect_name))
        return
    end
    local actor = world.GetActor(session.GetMyHandle())
    if not actor then
        g.vlog("muteki: actor が取れないのでエフェクトを出せない name=%s", tostring(effect_name))
        return
    end
    scale = tonumber(scale) or g.MUTEKI_DEFAULT_SCALE
    if force then
        Muteki_effect_transparency_up()
    end
    g.vlog("muteki: エフェクトを出す name=%s scale=%s force=%s", tostring(effect_name), tostring(scale),
        tostring(force))
    effect.PlayActorEffect(actor, effect_name, "None", g.MUTEKI_EFFECT_LIFETIME, scale)
end

-- UI エフェクトを描く入れ物。**専用のフレームを持つ。**
-- Muteki の枠（バフのゲージが並ぶ枠）は、出すバフが無い間は大きさ 0 で中身も無いので、
-- そこへ描いても何も見えない。設定画面から試し再生したときがまさにその状態になる。
-- 常時表示のマーカー扱いなので当たり判定は塞がない（docs/check_frame_hittest.py の ALLOW）。
function Muteki_effect_ui_holder()
    local ui_effect = g.create_persistent_frame(addon_name_lower .. "muteki_ui_effect")
    AUTO_CAST(ui_effect)
    ui_effect:SetSkinName("None")
    ui_effect:Resize(200, 200)
    ui_effect:SetLayerLevel(tonumber(g.muteki_settings.etc.layer_lv) or 80)
    -- バフのゲージが出ている枠の上に重ねる。枠がまだ無いときは画面の中央へ。
    local muteki = ui.GetFrame(addon_name_lower .. "muteki")
    if muteki then
        ui_effect:SetGravity(ui.LEFT, ui.TOP)
        ui_effect:SetOffset(muteki:GetX(), muteki:GetY())
    else
        ui_effect:SetGravity(ui.CENTER_HORZ, ui.CENTER_VERT)
    end
    ui_effect:ShowWindow(1)
    local holder = ui_effect:CreateOrGetControl("groupbox", "holder", 0, 0, 200, 200)
    AUTO_CAST(holder)
    holder:SetSkinName("None")
    holder:EnableHitTest(0)
    holder:ShowWindow(1)
    return ui_effect, holder
end

-- UI に描くエフェクト。システム設定の「自分のエフェクト透明度」の対象外。
-- 素の PlayUIEffect はコントロールの持ち物（フレームには無い）なので、上の入れ物へ出す。
-- **pcall で包む。** 名前が UI エフェクトとして登録されていないとここで落ちる可能性があり、
-- 落ちるとバフの処理ごと止まる。出なかったのか落ちたのかはログで区別する。
function Muteki_effect_play_ui(effect_name, scale)
    if not effect_name or effect_name == "" or effect_name == "None" then
        g.vlog("muteki: UI エフェクトは出さない指定 name=%s", tostring(effect_name))
        return
    end
    local ui_effect, holder = Muteki_effect_ui_holder()
    scale = tonumber(scale) or 12
    g.vlog("muteki: UI エフェクトを出す name=%s scale=%s 枠=(%s,%s) 見えている=%s", tostring(effect_name),
        tostring(scale), tostring(ui_effect:GetX()), tostring(ui_effect:GetY()),
        tostring(ui_effect:IsVisible()))
    local ok, err = pcall(function()
        holder:StopUIEffect("MUTEKI_UI_EFFECT", true, 0)
        holder:PlayUIEffect(effect_name, scale, "MUTEKI_UI_EFFECT")
    end)
    if not ok then
        g.vlog("muteki: UI エフェクトの再生で落ちた name=%s err=%s", tostring(effect_name), tostring(err))
        return
    end
    -- 出しっぱなしにしない。次を出すときは前のタイマーを捨ててから積み直す。
    ui_effect:StopUpdateScript("Muteki_effect_ui_stop")
    ui_effect:RunUpdateScript("Muteki_effect_ui_stop", g.MUTEKI_UI_EFFECT_TIME)
end

-- UI エフェクトを止める。RunUpdateScript は 0 を返すまで繰り返すので、1 回で止める。
function Muteki_effect_ui_stop(frame)
    local holder = GET_CHILD(frame, "holder")
    if holder then
        AUTO_CAST(holder)
        local ok, err = pcall(function()
            holder:StopUIEffect("MUTEKI_UI_EFFECT", true, 0.3)
        end)
        g.vlog("muteki: UI エフェクトを止めた ok=%s err=%s", tostring(ok), tostring(err))
    end
    return 0
end

-- 「自分のエフェクト透明度」を出している間だけ上げる。
-- **戻す値は設定 JSON にも控える。** g はマップ移動で作り直されるので、
-- 控えが g だけだと、上げた直後に移動したりクライアントが落ちたりしたときに
-- 利用者の設定を 255 のまま置き去りにしてしまう（初期化時に控えを見て戻す）。
function Muteki_effect_transparency_up()
    if g.muteki_transparency_saved then
        return -- すでに上げている。重ねて上書きしない（255 を控えてしまう）
    end
    local cur = config.GetMyEffectTransparency()
    if not cur or cur >= 255 then
        g.vlog("muteki: 透明度は元から濃い(%s)ので触らない", tostring(cur))
        return
    end
    g.muteki_transparency_saved = cur
    g.muteki_settings.etc.transparency_backup = cur
    Muteki_save_settings()
    config.SetMyEffectTransparency(255)
    g.vlog("muteki: 自分のエフェクト透明度を一時的に上げた %s -> 255", tostring(cur))
    local muteki = ui.GetFrame(addon_name_lower .. "muteki")
    if muteki then
        muteki:RunUpdateScript("Muteki_effect_transparency_back", g.MUTEKI_EFFECT_LIFETIME + 0.5)
    else
        Muteki_effect_transparency_back()
    end
end

function Muteki_effect_transparency_back(frame)
    local saved = g.muteki_transparency_saved or g.muteki_settings.etc.transparency_backup
    if saved then
        config.SetMyEffectTransparency(saved)
        g.vlog("muteki: 自分のエフェクト透明度を戻した -> %s", tostring(saved))
    end
    g.muteki_transparency_saved = nil
    if g.muteki_settings.etc.transparency_backup then
        g.muteki_settings.etc.transparency_backup = nil
        Muteki_save_settings()
    end
    return 0
end

local function muteki_trans(text)
    local trans_text = g.muteki_trans_tbl["etc"][text]
    if g.lang == "Japanese" or g.lang == "kr" then
        trans_text = g.muteki_trans_tbl[g.lang][text]
    end
    return trans_text
end

function Muteki_save_settings()
    g.save_json(g.muteki_path, g.muteki_settings)
end

function Muteki_load_settings()
    g.muteki_path = string.format("../addons/%s/%s/muteki.json", addon_name_lower, g.active_id)
    g.muteki_old_path = string.format("../addons/%s/settings_2510.json", "muteki2ex")
    local settings = g.load_json(g.muteki_path)
    if not settings then
        local old_settings = g.load_json(g.muteki_old_path)
        if old_settings then
            local valid_cids = {}
            local sys_opt_path = string.format("../release/addon_setting/system_option/%s/settings.json", g.active_id)
            local sys_opt_file = io.open(sys_opt_path, "r")
            if sys_opt_file then
                local content = sys_opt_file:read("*a")
                sys_opt_file:close()
                if content and content ~= "" then
                    local status, data = pcall(json.decode, content)
                    if status and data and data.pc_id then
                        for k, _ in pairs(data.pc_id) do
                            valid_cids[tostring(k)] = true
                        end
                    end
                end
            end
            settings = {
                etc = {},
                buff_list = {}
            }
            settings.etc.rotate = old_settings.rotate or 0
            settings.etc.hide_time = old_settings.hide_time or 300
            settings.etc.mode = old_settings.mode or "fixed"
            settings.etc.layer_lv = old_settings.layer_lv or 80
            if old_settings.pos then
                settings.etc.x = old_settings.pos.x
                settings.etc.y = old_settings.pos.y
                settings.etc.lock = old_settings.pos.lock and 0 or 1
            else
                settings.etc.x = 480
                settings.etc.y = 640
                settings.etc.lock = 1
            end
            if old_settings.buff_list then
                local function filter_manage_table(source)
                    local target = {}
                    if source then
                        for cid, list in pairs(source) do
                            if valid_cids[tostring(cid)] and type(list) == "table" and next(list) then
                                local new_list = {}
                                for k, v in pairs(list) do
                                    if type(v) == "boolean" then
                                        new_list[k] = v and 1 or 0
                                    else
                                        new_list[k] = v
                                    end
                                end
                                target[cid] = new_list
                            end
                        end
                    end
                    return target
                end
                for buff_id, data in pairs(old_settings.buff_list) do
                    local new_data = {}
                    new_data.color = data.color
                    new_data.nico_chat = data.nico_chat
                    new_data.effect_check = data.effect_check
                    new_data.end_sound = data.end_sound
                    new_data.pt_chat = data.pt_chat and 1 or 0
                    new_data.circle_icon = data.circle_icon and 1 or 0
                    new_data.count_display = data.count_display and 1 or 0
                    local new_not_notify = {}
                    if data.not_notify then
                        for cid, val in pairs(data.not_notify) do
                            if valid_cids[tostring(cid)] then
                                new_not_notify[cid] = (val == true or val == 1) and 1 or 0
                            end
                        end
                    end
                    new_data.not_notify = new_not_notify
                    new_data.debuffs = filter_manage_table(data.debuff_manage)
                    new_data.buffs = filter_manage_table(data.buff_manage)
                    settings.buff_list[buff_id] = new_data
                end
            end
        else
            settings = {
                etc = {
                    mode = "fixed",
                    layer_lv = 80,
                    hide_time = 300,
                    rotate = 0,
                    lock = 1,
                    y = 640,
                    x = 480
                },
                buff_list = {}
            }
        end
    end
    g.muteki_settings = settings
    Muteki_save_settings()
end

function muteki_on_init()
    if not g.muteki_settings then
        Muteki_load_settings()
    end
    local old_func = g.settings.muteki.old_init_func
    if _G[old_func] then
        return
    end
    g.register_msg("BUFF_ADD", "Muteki_BUFF_ON_MSG")
    g.register_msg("BUFF_UPDATE", "Muteki_BUFF_ON_MSG")
    g.register_msg("BUFF_REMOVE", "Muteki_BUFF_ON_MSG")
    g.setup_hook_and_event(g.addon, "ICON_USE", "Muteki_ICON_USE", true)
    if g.settings.muteki.use == 0 then
        ui.DestroyFrame(addon_name_lower .. "muteki")
        return
    end
    g.muteki_default_color = "FFCCCC22"
    g.muteki_buffs = {
        circle = {},
        gauge = {}
    }
    g.muteki_time_buffs = {}
    g.muteki_buff_count = {}
    g.muteki_highlander = false
    if g.map_name == "c_highlander" then
        g.muteki_highlander = true
    end
    Muteki_buff_frame_init()
    Muteki_skill_list()
    if g.muteki_overload and g.muteki_overload.cid == g.cid then
        if g.muteki_overload.is_cool == 1 then
            local now = imcTime.GetAppTime()
            local elapsed = now - g.muteki_overload.start_time
            local remain = 50 - elapsed
            if remain > 0 then
                local buff_id = g.muteki_overload.buff_id
                local buff_id_str = tostring(buff_id)
                local buff_data = g.muteki_settings.buff_list[buff_id_str]
                if buff_data then
                    g.muteki_buffs[buff_id_str] = {
                        show = true,
                        effect = false,
                        start_time = now,
                        set_time = remain,
                        notify = 1
                    }
                    g.muteki_buff_count[buff_id_str] = 1
                    local list_type = (buff_data.circle_icon == 1) and "circle" or "gauge"
                    Muteki_insert_if_not_exists(g.muteki_buffs[list_type], buff_id)
                    local muteki = ui.GetFrame(addon_name_lower .. "muteki")
                    local buff_cls = GetClassByType('Buff', buff_id)
                    Muteki_buff_frame(muteki, "BUFF_ADD", buff_id, buff_cls, buff_data, (buff_data.circle_icon == 1))
                    Muteki_child_set_pos(muteki)
                end
            else
                g.muteki_overload = nil
            end
        end
    end
    local _nexus_addons_p = ui.GetFrame("_nexus_addons_p")
    _nexus_addons_p:RunUpdateScript("Muteki_buffslot_script", 2.0)
end

-- バフの開始 / 終了をパーティーチャット・ニコチャットへ流す処理は、**エンジンの
-- BUFF_ADD / BUFF_REMOVE のディスパッチの中から送ってはいけない。**
-- 送るとクライアントがアクセス違反で落ちる(yoma16版 new_nexus_addons v1.0.6 以降の
-- v1.1.2 でクラッシュダンプから特定されたもの。**ネイティブのクラッシュなので
-- Lua のエラーにならず、debug_log.txt にも verbose_log.txt にも何も残らない**)。
--
-- 文面はその場で組み立てる(1 tick 後にはバフのデータが消えていることがある)。
-- **遅らせるのは送信だけ。** 0.1 秒後に外から流し直す。
--
-- ReserveScript はフレームに紐付かないので、バフのアイコンやフレームの表示状態に
-- 左右されない(フレーム側の RunUpdateScript は隠れている間は回らない)。
function Muteki_defer_chat(kind, text)
    g.muteki_chat_queue = g.muteki_chat_queue or {}
    table.insert(g.muteki_chat_queue, {
        kind = kind,
        text = text
    })
    -- 溜まっているぶんはまとめて 1 回で流れる(flush が先頭で入れ物を空にするので、
    -- 余分に予約された分は空振りするだけ)。
    ReserveScript("Muteki_flush_chat()", 0.1)
end

function Muteki_flush_chat()
    local queue = g.muteki_chat_queue
    if not queue or #queue == 0 then
        return
    end
    g.muteki_chat_queue = {}
    for _, item in ipairs(queue) do
        -- 1 件が失敗しても残りは流す。ここで落ちても呼び元(ReserveScript)は
        -- バフのディスパッチの外なので、クライアントは巻き込まれない。
        local ok, err = pcall(function()
            if item.kind == "pt" then
                ui.Chat(item.text)
            else
                NICO_CHAT(item.text)
            end
        end)
        if not ok then
            g.vlog("muteki: バフ通知の送信に失敗 kind=%s err=%s", tostring(item.kind), tostring(err))
        end
    end
    g.vlog("muteki: バフ通知を %d 件、バフの処理の外から送った", #queue)
end

function Muteki_BUFF_ON_MSG(frame, msg, is_dummy, buff_id)
    if g.settings.muteki.use == 0 then
        return
    end
    local buff_id_str = tostring(buff_id)
    local buff_data = g.muteki_settings.buff_list[buff_id_str]
    local muteki = ui.GetFrame(addon_name_lower .. "muteki")
    muteki:SetAlpha(10)
    local notify_val = 0
    if buff_data and buff_data.not_notify then
        notify_val = buff_data.not_notify[g.cid] or 0
    end
    if (buff_data and notify_val == 0) or is_dummy == "dummy" then
        local now = imcTime.GetAppTime()
        if g.muteki_buffs[buff_id_str] and g.muteki_buffs[buff_id_str].start_time then
            if now - g.muteki_buffs[buff_id_str].start_time < 0.5 then
                return
            end
        end
        local is_circle = false
        if buff_data.circle_icon == 1 then
            is_circle = true
        end
        local buff_cls = GetClassByType('Buff', buff_id)
        local buff_name = buff_cls.Name
        local overload_tbl = {4483, 4757}
        if buff_id == overload_tbl[1] or buff_id == overload_tbl[2] then
            local my_handle = session.GetMyHandle()
            local info_buff = info.GetBuff(my_handle, buff_id)
            if info_buff then
                g.muteki_overload = {
                    start_time = now, -- imcTime
                    buff_id = buff_id,
                    is_cool = 0,
                    cid = g.cid
                }
                g.muteki_buffs[buff_id_str] = nil
            else
                if g.muteki_overload and g.muteki_overload.is_cool == 0 and msg == "BUFF_REMOVE" then
                    g.muteki_time_buffs[buff_id_str] = {
                        show = false,
                        effect = false,
                        start_time = now,
                        set_time = 20,
                        notify = 1
                    }
                    g.muteki_overload.is_cool = 1
                    Muteki_BUFF_ON_MSG(frame, 'BUFF_ADD', is_dummy, buff_id)
                    return
                else
                    if not (g.muteki_overload and g.muteki_overload.is_cool == 1) then
                        g.muteki_overload = nil
                    end
                end
            end
        end
        if msg == 'BUFF_ADD' then
            g.muteki_remove_notice = g.muteki_remove_notice or {}
            g.muteki_remove_notice[buff_id_str] = 0
            g.muteki_buff_count = g.muteki_buff_count or {}
            g.muteki_buff_count[buff_id_str] = (g.muteki_buff_count[buff_id_str] or 0) + 1
            if g.muteki_time_buffs and g.muteki_time_buffs[buff_id_str] then
                g.muteki_buffs[buff_id_str] = g.muteki_time_buffs[buff_id_str]
                g.muteki_time_buffs[buff_id_str] = nil
            elseif not g.muteki_buffs[buff_id_str] then
                g.muteki_buffs[buff_id_str] = {
                    show = false,
                    effect = false,
                    start_time = now,
                    set_time = nil,
                    notify = 0
                }
            end
            g.muteki_buffs.circle = g.muteki_buffs.circle or {}
            g.muteki_buffs.gauge = g.muteki_buffs.gauge or {}
            if is_circle then
                Muteki_insert_if_not_exists(g.muteki_buffs.circle, buff_id)
            else
                Muteki_insert_if_not_exists(g.muteki_buffs.gauge, buff_id)
            end
            if g.muteki_buffs[buff_id_str] and g.muteki_buffs[buff_id_str].notify == 0 then
                if buff_data.pt_chat == 1 then
                    if not string.find(buff_cls.Name, "NoData") then
                        Muteki_defer_chat("pt", string.format("/p %s start", buff_cls.Name))
                    end
                end
                if buff_data.nico_chat == 1 then
                    Muteki_defer_chat("nico", string.format("{@st55_a}%s start", buff_name))
                end
                if Muteki_effect_enabled(buff_data, "start") then
                    Muteki_effect_fire(buff_data, "start")
                end
                g.muteki_buffs[buff_id_str].notify = 1
            end
            if g.muteki_buff_count[buff_id_str] > 0 then
                Muteki_child_set_pos(muteki)
            end
            Muteki_buff_frame(muteki, msg, buff_id, buff_cls, buff_data, is_circle)
        elseif msg == 'BUFF_REMOVE' then
            if g.muteki_buffs[buff_id_str] and g.muteki_buffs[buff_id_str].set_time then
                local now = imcTime.GetAppTime()
                if g.muteki_buffs[buff_id_str].set_time - (now - g.muteki_buffs[buff_id_str].start_time) > 0 then
                    return
                end
            end
            if is_dummy ~= "dummy" then
                Muteki_handle_buff_end(muteki, buff_id)
            end
            Muteki_child_set_pos(muteki)
        elseif msg == 'BUFF_UPDATE' then
            if not g.muteki_buffs[buff_id_str] then
                g.muteki_buffs[buff_id_str] = {
                    show = false,
                    effect = false,
                    start_time = imcTime.GetAppTime(),
                    set_time = nil,
                    notify = 0
                }
            end
            Muteki_buff_frame(muteki, msg, buff_id, buff_cls, buff_data, is_circle)
        end
    end
end

function Muteki_handle_buff_end(notice_frame, buff_id)
    local buff_id_str = tostring(buff_id)
    local buff_data = g.muteki_settings.buff_list[buff_id_str]
    local buff_cls = GetClassByType('Buff', buff_id)
    local notice = false
    if g.muteki_remove_notice and g.muteki_remove_notice[buff_id_str] == 0 then
        notice = true
        g.muteki_remove_notice[buff_id_str] = 1
    end
    if notice then
        if buff_data.pt_chat == 1 then
            if not string.find(buff_cls.Name, "NoData") then
                Muteki_defer_chat("pt", string.format("/p %s end", buff_cls.Name))
            end
        end
        if buff_data.nico_chat == 1 then
            Muteki_defer_chat("nico", string.format("{@st55_a}%s end", buff_cls.Name))
        end
        if buff_data.end_sound == 1 then
            imcSound.PlaySoundEvent("sys_transcend_cast")
        end
    end
    if g.muteki_buffs[buff_id_str] then
        g.muteki_buffs[buff_id_str] = nil
    end
    if g.muteki_buff_count[buff_id_str] then
        g.muteki_buff_count[buff_id_str] = nil
    end
    local ui_types = {"circle", "gauge"}
    for _, ui_type in ipairs(ui_types) do
        local child_name = ui_type .. "_" .. buff_id
        local child = GET_CHILD(notice_frame, child_name)
        if child then
            local target_list = g.muteki_buffs[ui_type]
            if target_list then
                for i = #target_list, 1, -1 do
                    if target_list[i] == buff_id then
                        table.remove(target_list, i)
                        break
                    end
                end
            end
            DESTROY_CHILD_BYNAME(notice_frame, child_name)
        end
    end
end

function Muteki_ICON_USE(my_frame, my_msg)
    if g.settings.muteki.use == 0 then
        return
    end
    local icon, reAction = g.get_event_args(my_msg)
    if icon then
        AUTO_CAST(icon)
        local cur_time = ICON_UPDATE_SKILL_COOLDOWN(icon)
        if cur_time > 0 then
            return
        end
        local icon_info = icon:GetInfo()
        if icon_info:GetCategory() == 'Skill' then
            local skill_id = icon_info.type
            local skill_id_str = tostring(skill_id)
            -- **引く前に g.muteki_skills を確かめること。** ICON_USE はこのアドオンが
            -- 面倒を見ていないスキルアイコンにも来るので、未登録なら何もせず帰る。
            -- 以前は次の if で .buff_id を引いてから存在確認しており、未登録のスキルを
            -- 使うたびに必ず落ちていた(debug_log.txt に 2026-07-29 以降 十数件。
            -- msg の失敗報告は (メッセージ, ハンドラ) ごとに 1 回だけなので気付きにくい)。
            local skill_list = g.muteki_skills[skill_id_str]
            if not skill_list then
                return
            end
            if g.muteki_buffs[skill_list.buff_id] then
                return
            end
            g.muteki_time_buffs[skill_list.buff_id] = {
                show = false,
                effect = false,
                start_time = imcTime.GetAppTime(),
                set_time = skill_list.time,
                notify = 0
            }
            Muteki_BUFF_ON_MSG("", 'BUFF_ADD', "", tonumber(skill_list.buff_id))
        end
    end
end

function Muteki_SET_BUFF_SLOT(my_frame, my_msg)
    local slot, capt, class, buff_type = g.get_event_args(my_msg)
    AUTO_CAST(slot)
    slot:SetEventScript(ui.LBUTTONDOWN, 'Muteki_add_buff_msg')
    slot:SetEventScriptArgString(ui.LBUTTONDOWN, class.Name)
    slot:SetEventScriptArgNumber(ui.LBUTTONDOWN, buff_type)
end

function Muteki_buffslot_script(_nexus_addons_p)
    if s_buff_ui and s_buff_ui.slotlist then
        for i = 0, s_buff_ui["buff_group_cnt"] do
            local slotlist = s_buff_ui["slotlist"][i]
            local slotcount = s_buff_ui["slotcount"][i]
            local captionlist = s_buff_ui["captionlist"][i]
            if slotcount ~= nil and slotcount >= 0 then
                for i = 0, slotcount - 1 do
                    local slot = slotlist[i]
                    AUTO_CAST(slot)
                    local icon = slot:GetIcon()
                    local icon_info = icon:GetInfo()
                    local buff_id = icon_info.type
                    if buff_id ~= 0 then
                        local buff_cls = GetClassByType("Buff", buff_id)
                        slot:SetEventScript(ui.LBUTTONDOWN, 'Muteki_add_buff_msg')
                        slot:SetEventScriptArgString(ui.LBUTTONDOWN, buff_cls.Name)
                        slot:SetEventScriptArgNumber(ui.LBUTTONDOWN, buff_id)
                    end
                end
            end
        end
        g.setup_hook_and_event(g.addon, 'SET_BUFF_SLOT', "Muteki_SET_BUFF_SLOT", true)
    end
    return 0
end

function Muteki_buff_frame_init()
    -- 前回、透明度を上げたまま終わっていたら（マップ移動 / 強制終了）ここで戻す。
    if g.muteki_settings and g.muteki_settings.etc and g.muteki_settings.etc.transparency_backup then
        Muteki_effect_transparency_back()
    end
    -- ESC で消えない土台で作る(理由は g.create_persistent_frame のコメント)。
    local muteki = g.create_persistent_frame(addon_name_lower .. "muteki")
    AUTO_CAST(muteki)
    muteki:SetSkinName("None")
    if g.muteki_settings.etc.mode == "fixed" then
        muteki:SetOffset(g.muteki_settings.etc.x, g.muteki_settings.etc.y)
        muteki:StopUpdateScript("_FRAME_AUTOPOS")
    else
        local handle = session.GetMyHandle()
        FRAME_AUTO_POS_TO_OBJ(muteki, handle, muteki:GetWidth() - 145, 50, 3, 1)
        g.muteki_settings.etc.lock = 0
        Muteki_save_settings()
        local settings = ui.GetFrame(addon_name_lower .. "muteki_settings")
        if settings then
            AUTO_CAST(settings)
            local move_toggle = GET_CHILD_RECURSIVELY(settings, "move_toggle")
            AUTO_CAST(move_toggle)
            local icon_name = "test_com_ability_on"
            move_toggle:SetImage(icon_name)
        end
    end
    muteki:SetLayerLevel(g.muteki_settings.etc.layer_lv)
    muteki:EnableHittestFrame(g.muteki_settings.etc.lock)
    muteki:EnableMove(g.muteki_settings.etc.lock)
    if g.muteki_settings.etc.lock == 1 then
        local title = muteki:CreateOrGetControl("richtext", "title", 0, 0, 40, 10)
        AUTO_CAST(title)
        title:SetGravity(ui.LEFT, ui.TOP)
        title:SetText("{ol}{s10}Muteki")
        muteki:SetSkinName("chat_window")
        muteki:Resize(100, 20)
        muteki:SetAlpha(10)
    else
        muteki:RemoveChild("title")
        muteki:Resize(250, 210)
    end
    muteki:ShowWindow(1)
    muteki:SetEventScript(ui.LBUTTONUP, "Muteki_notic_frame_end_drag")
end

function Muteki_notic_frame_end_drag(muteki)
    g.muteki_settings.etc.x = muteki:GetX()
    g.muteki_settings.etc.y = muteki:GetY()
    Muteki_save_settings()
end

function Muteki_buff_frame(notice_frame, msg, buff_id, buff_cls, buff_data, is_circle)
    local buff_id_str = tostring(buff_id)
    local my_handle = session.GetMyHandle()
    local info_buff = info.GetBuff(my_handle, buff_id) or
                          (g.muteki_buffs[buff_id_str] and g.muteki_buffs[buff_id_str].set_time)
    if not info_buff then
        return
    end
    local image_name = GET_BUFF_ICON_NAME(buff_cls)
    if image_name == "icon_None" then
        image_name = "icon_item_nothing"
    end
    if msg == "BUFF_ADD" then
        local is_cool = false
        if g.muteki_overload and g.muteki_overload.is_cool == 1 and g.muteki_overload.buff_id == buff_id then
            is_cool = true
        end
        local child
        local start_time_sec = 0
        if is_circle then
            child = notice_frame:CreateOrGetControl("picture", "circle_" .. buff_id, 50, 5, 50, 50)
            AUTO_CAST(child)
            child:SetImage(image_name)
            if g.muteki_settings.etc.rotate == 1 then
                child:SetAngleLoop(3)
            end
            if is_cool then
                child:SetColorTone("FF696969")
            end
            child:SetEnableStretch(1)
            child:EnableHitTest(0)
        else -- gauge
            child = notice_frame:CreateOrGetControl("picture", "gauge_" .. buff_id, 0, 60, 250, 20)
            AUTO_CAST(child)
            child:SetEnableStretch(1)
            child:EnableHitTest(0)
            local gauge_back = child:CreateOrGetControl("picture", "gauge_back", 0, 10, 250, 10)
            AUTO_CAST(gauge_back)
            gauge_back:SetImage("fullblack")
            gauge_back:SetEnableStretch(1)
            gauge_back:EnableHitTest(0)
            local gauge_front = child:CreateOrGetControl("picture", "gauge_front", 0, 10, 250, 10)
            AUTO_CAST(gauge_front)
            gauge_front:SetImage("fullwhite")
            gauge_front:SetEnableStretch(1)
            gauge_front:EnableHitTest(0)
            if is_cool then
                gauge_front:SetColorTone("FFFFFFFF")
            else
                gauge_front:SetColorTone(buff_data.color)
            end
            local buff_name_ctrl = child:CreateOrGetControl("richtext", "buff_name", 0, 0, 10, 20)
            buff_name_ctrl:SetText(string.format("{ol}{s12}{img %s 15 15}%s", image_name, buff_cls.Name))
            buff_name_ctrl:AdjustFontSizeByWidth(170)
        end
        child:SetUserValue("BUFF_ID", buff_id)
        child:SetEnableStretch(1)
        child:EnableHitTest(0)
        if type(info_buff) == "number" then
            start_time_sec = info_buff
        elseif g.muteki_buffs[buff_id_str] and g.muteki_buffs[buff_id_str].set_time then
            local now = imcTime.GetAppTime()
            start_time_sec = g.muteki_buffs[buff_id_str].set_time - (g.muteki_buffs[buff_id_str].start_time - now)
        else
            start_time_sec = info_buff.time / 1000
        end
        child:SetUserValue("START_TIME", start_time_sec)
        local buff_time_ctrl = child:CreateOrGetControl("richtext", "buff_time", 0, 0, 50, 30)
        AUTO_CAST(buff_time_ctrl)
        if buff_data.count_display == 1 and type(info_buff) ~= "number" then
            local buff_over_ctrl = child:CreateOrGetControl("richtext", "buff_over", 0, 0, 0, 0)
            AUTO_CAST(buff_over_ctrl)
            if is_circle then
                buff_over_ctrl:Resize(20, 20)
                buff_over_ctrl:SetGravity(ui.RIGHT, ui.BOTTOM)
                if start_time_sec > 0 then
                    buff_over_ctrl:SetText(string.format("{ol}{s22}%d", info_buff.over))
                    buff_time_ctrl:SetGravity(ui.LEFT, ui.TOP)
                else
                    buff_over_ctrl:SetText(string.format("{ol}{s35}%d", info_buff.over))
                    local rect = buff_over_ctrl:GetMargin();
                    buff_over_ctrl:SetMargin(rect.left, rect.top, rect.right + 12, rect.bottom + 5)
                end
            else -- gauge
                buff_over_ctrl:Resize(30, 20)
                buff_over_ctrl:SetOffset(220, 0)
                buff_over_ctrl:SetGravity(ui.RIGHT, ui.CENTER_VERT)
                buff_over_ctrl:SetText(string.format("{ol}{s20}%d", info_buff.over))
            end
            buff_over_ctrl:SetColorTone("FFFFFF00")
        elseif not is_circle then
            buff_time_ctrl:SetOffset(180, 0)
            buff_time_ctrl:Resize(30, 20)
            buff_time_ctrl:SetGravity(ui.RIGHT, ui.TOP)
            local r = buff_time_ctrl:GetMargin()
            buff_time_ctrl:SetMargin(r.left, r.top, r.right + 40, r.bottom)
        elseif is_circle then
            buff_time_ctrl:SetGravity(ui.RIGHT, ui.TOP)
            local r = buff_time_ctrl:GetMargin()
            buff_time_ctrl:SetMargin(r.left, r.top + 10, r.right, r.bottom)
        end
        Muteki_notice_update(child)
        if not child:HaveUpdateScript("Muteki_notice_update") then
            child:RunUpdateScript("Muteki_notice_update", 0.1)
        end
    elseif msg == "BUFF_UPDATE" then
        local ui_type = is_circle and "circle" or "gauge"
        local child = GET_CHILD(notice_frame, ui_type .. "_" .. buff_id)
        if child then
            local buff_over_ctrl = GET_CHILD(child, "buff_over")
            if buff_over_ctrl and type(info_buff) ~= "number" then
                local stat
                if is_circle then
                    stat = (info_buff.time <= 0) and string.format("{ol}{s35}%d", info_buff.over) or
                               string.format("{ol}{s22}%d", info_buff.over)
                else -- gauge
                    stat = string.format("{ol}{s20}%d", info_buff.over)
                end
                buff_over_ctrl:SetText(stat)
                buff_over_ctrl:SetColorTone("FFFFFF00")
                if buff_cls.OverBuff <= info_buff.over then
                    if not g.muteki_buffs[buff_id_str].effect then
                        -- 音は「重複が最大になった」こと自体の知らせなので、
                        -- エフェクトを OFF にしても鳴らす
                        if Muteki_effect_enabled(buff_data, "over") then
                            Muteki_effect_fire(buff_data, "over")
                        end
                        imcSound.PlaySoundEvent("sys_cube_open_jackpot")
                        g.muteki_buffs[buff_id_str].effect = true
                    end
                    buff_over_ctrl:SetColorTone("FFFF0000")
                end
            end
            child:StopUpdateScript("Muteki_notice_update")
            Muteki_notice_update(child)
            if not child:HaveUpdateScript("Muteki_notice_update") then
                child:RunUpdateScript("Muteki_notice_update", 0.1)
            end
        end
    end
end

function Muteki_notice_update(child)
    local child_name = child:GetName()
    local muteki = child:GetParent()
    local buff_id = child:GetUserIValue("BUFF_ID")
    local buff_id_str = tostring(buff_id)
    local my_handle = session.GetMyHandle()
    local cur_time = Muteki_get_remaining_time(buff_id)
    local ui_type = string.find(child:GetName(), "circle_") and "circle" or "gauge"
    if cur_time <= 0 then
        Muteki_BUFF_ON_MSG(nil, "BUFF_REMOVE", "", buff_id)
        return 0
    end
    if (cur_time <= g.muteki_settings.etc.hide_time) or (cur_time == math.huge) then
        child:ShowWindow(1)
        g.muteki_buffs[buff_id_str].show = true
    else
        child:ShowWindow(0)
        g.muteki_buffs[buff_id_str].show = false
    end
    Muteki_child_set_pos(muteki)
    if g.muteki_buffs[buff_id_str].show == false then
        return 1
    end
    if ui_type == "circle" then
        if cur_time == math.huge then
            local buff_over_ctrl = GET_CHILD(child, "buff_over")
            buff_over_ctrl:ShowWindow(1)
        elseif cur_time > 0 then
            local stat = string.format("{ol}{s22}%.1f", cur_time)
            if cur_time >= 60 then
                local min = math.floor(cur_time / 60)
                stat = string.format("{ol}{s22}%d{s10}%s", min, "min")
            elseif cur_time <= 10 and cur_time > 5 then
                stat = string.format("{ol}{s22}{#FF4500}%.1f", cur_time)
            elseif cur_time <= 5 then
                stat = string.format("{ol}{s22}{#FF0000}%.1f", cur_time)
            end
            local buff_time_ctrl = GET_CHILD(child, "buff_time")
            if buff_time_ctrl then
                buff_time_ctrl:SetText(stat)
            end
        end
    elseif ui_type == "gauge" then
        local buff_time_ctrl = GET_CHILD(child, "buff_time")
        if cur_time > 0 and cur_time ~= math.huge then
            buff_time_ctrl:ShowWindow(1)
            buff_time_ctrl:SetText(string.format("{ol}{s18}%.1f", cur_time))
            buff_time_ctrl:SetColorTone(g.muteki_settings.buff_list[buff_id_str].color)
        else
            buff_time_ctrl:ShowWindow(0)
        end
        local start_time = tonumber(child:GetUserValue("START_TIME"))
        local ratio = 0
        if cur_time == math.huge then
            ratio = 1.0
        elseif start_time > 0 then
            ratio = cur_time / start_time
        end
        local gauge_front = GET_CHILD(child, "gauge_front")
        AUTO_CAST(gauge_front)
        if gauge_front then
            gauge_front:Resize(250 * ratio, 10)
        end
        local gauge_front = GET_CHILD(child, "gauge_front")
        AUTO_CAST(gauge_front)
    end
    return 1
end

function Muteki_child_set_pos(muteki)
    local circle_count = Muteki_reorder_ui_elements(muteki, "circle")
    local gauge_count = Muteki_reorder_ui_elements(muteki, "gauge")
    local x = circle_count * 50 + 50
    if x < 250 then
        x = 250
    end
    local y = gauge_count * 25 + 60
    if y < 60 then
        y = 60
    end
    muteki:Resize(x, y)
end

function Muteki_reorder_ui_elements(muteki, ui_type)
    local sorted_list = {}
    local source_list = g.muteki_buffs[ui_type]
    if source_list and type(source_list) == "table" then
        for _, buff_id in ipairs(source_list) do
            local cur_time = Muteki_get_remaining_time(buff_id)
            if cur_time > 0 then
                table.insert(sorted_list, {
                    buff_id = buff_id,
                    time = cur_time
                })
            end
        end
    end
    table.sort(sorted_list, function(a, b)
        return a.time < b.time
    end)
    local visible_count = 0
    for _, entry in ipairs(sorted_list) do
        local child = GET_CHILD(muteki, ui_type .. "_" .. entry.buff_id)
        if child and child:IsVisible() == 1 then
            if ui_type == "circle" then
                child:SetOffset((visible_count + 1) * 50, 5)
            else -- gauge
                child:SetOffset(0, visible_count * 25 + 60)
            end
            visible_count = visible_count + 1
            if not child:HaveUpdateScript("Muteki_notice_update") then
                child:RunUpdateScript("Muteki_notice_update", 0.1)
            end
        end
    end
    return visible_count
end

function Muteki_get_remaining_time(buff_id)
    local buff_id_str = tostring(buff_id)
    local my_handle = session.GetMyHandle()
    if g.muteki_buffs[buff_id_str] and g.muteki_buffs[buff_id_str].set_time then
        local elapsed_time = imcTime.GetAppTime() - g.muteki_buffs[buff_id_str].start_time
        return g.muteki_buffs[buff_id_str].set_time - elapsed_time
    end
    local info_buff = info.GetBuff(my_handle, buff_id)
    if info_buff then
        if info_buff.time > 0 then
            return info_buff.time / 1000
        elseif info_buff.time == 0 and info_buff.over > 0 then
            return math.huge
        end
    end
    return 0
end

function Muteki_insert_if_not_exists(list, value)
    for _, existing_value in ipairs(list) do
        if existing_value == value then
            return
        end
    end
    table.insert(list, value)
end

function Muteki_refresh_active_buffs()
    local my_handle = session.GetMyHandle()
    if g.muteki_settings.buff_list then
        for b_id_str, buff_data in pairs(g.muteki_settings.buff_list) do
            local b_id = tonumber(b_id_str)
            local info_buff = info.GetBuff(my_handle, b_id)
            if info_buff then
                local not_notify_val = buff_data.not_notify and buff_data.not_notify[g.cid]
                if not_notify_val == 1 then
                    Muteki_BUFF_ON_MSG("", "BUFF_REMOVE", "dummy", b_id)
                else
                    Muteki_BUFF_ON_MSG("", "BUFF_REMOVE", "", b_id)
                    Muteki_BUFF_ON_MSG("", "BUFF_ADD", "", b_id)
                    Muteki_BUFF_ON_MSG("", "BUFF_UPDATE", "", b_id)
                end
            end
        end
    end
end

function Muteki_skill_list()
    g.muteki_skills = {}
    local buff_list = g.muteki_settings.buff_list
    for buff_id, buff_data in pairs(buff_list) do
        Muteki_process_management_data(buff_data.debuffs, "debuff_time", buff_id)
        Muteki_process_management_data(buff_data.buffs, "buff_time", buff_id)
    end
end

function Muteki_process_management_data(tbl, time_key, buff_id)
    if not tbl then
        return
    end
    for cid, info in pairs(tbl) do
        if type(info) == "table" and info.skill_id and info[time_key] then
            if cid == g.cid and info[time_key] > 0 then
                local skill_id = info.skill_id
                g.muteki_skills[tostring(skill_id)] = {
                    time = info[time_key],
                    buff_id = buff_id
                }
            end
        end
    end
end

function Muteki_setting_frame_init()
    local settings = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "muteki_settings", 0, 50, 0, 0)
    AUTO_CAST(settings)
    g.block_click_through(settings)
    settings:SetSkinName("test_frame_low")
    settings:Resize(600, 1005)
    settings:SetGravity(ui.LEFT, ui.TOP)
    settings:SetOffset(0, 30)
    settings:SetLayerLevel(999)
    local title_gb = settings:CreateOrGetControl("groupbox", "title_gb", 0, 0, 600, 110)
    AUTO_CAST(title_gb)
    title_gb:SetSkinName("test_frame_top")
    local title_text = title_gb:CreateOrGetControl("richtext", "title_text", 0, 0, ui.CENTER_HORZ, ui.TOP, 0, 15, 0, 0)
    AUTO_CAST(title_text);
    title_text:SetText('{ol}{s28}MUTEKI Settings')
    local x = 0
    local buff_time = title_gb:CreateOrGetControl('richtext', 'buff_time', 15, 60, 100, 30)
    AUTO_CAST(buff_time)
    buff_time:SetText(muteki_trans('buff_time'))
    x = buff_time:GetWidth() + 15
    local buff_time_edit = title_gb:CreateOrGetControl('edit', 'buff_time_edit', x, 60, 60, 20)
    AUTO_CAST(buff_time_edit)
    buff_time_edit:SetNumberMode(1)
    buff_time_edit:SetFontName("white_16_ol")
    buff_time_edit:SetText(g.muteki_settings.etc.hide_time)
    buff_time_edit:SetTextAlign("center", "top")
    buff_time_edit:SetTypingScp("Muteki_change_settings")
    buff_time_edit:SetEventScript(ui.ENTERKEY, 'Muteki_change_settings')
    x = x + buff_time_edit:GetWidth() + 20
    local layer = title_gb:CreateOrGetControl('richtext', 'layer', x, 60, 10, 30)
    AUTO_CAST(layer)
    layer:SetText(muteki_trans('layer_lv'))
    x = x + layer:GetWidth()
    local layer_edit = title_gb:CreateOrGetControl('edit', 'layer_edit', x, 60, 50, 20)
    AUTO_CAST(layer_edit)
    layer_edit:SetNumberMode(1)
    layer_edit:SetFontName("white_16_ol")
    layer_edit:SetText(g.muteki_settings.etc.layer_lv or 80)
    layer_edit:SetTextAlign("center", "top")
    layer_edit:SetTypingScp("Muteki_change_settings")
    layer_edit:SetEventScript(ui.ENTERKEY, 'Muteki_change_settings')
    x = 0
    local mode = title_gb:CreateOrGetControl('richtext', 'mode', 15, 85, 10, 30)
    AUTO_CAST(mode)
    mode:SetText(muteki_trans('position_mode'))
    x = mode:GetWidth() + 15
    local mode_toggle = title_gb:CreateOrGetControl('picture', "mode_toggle", x, 80, 60, 25);
    AUTO_CAST(mode_toggle)
    local icon_name = "test_com_ability_on"
    if g.muteki_settings.etc.mode == "fixed" then
        icon_name = "test_com_ability_off"
    end
    mode_toggle:SetImage(icon_name)
    mode_toggle:SetEnableStretch(1)
    mode_toggle:EnableHitTest(1)
    mode_toggle:SetTextTooltip(muteki_trans("mode_desc"))
    mode_toggle:SetEventScript(ui.LBUTTONUP, "Muteki_change_settings")
    x = x + mode_toggle:GetWidth() + 10
    local move = title_gb:CreateOrGetControl('richtext', 'move', x, 85, 10, 30)
    AUTO_CAST(move)
    move:SetText(muteki_trans('frame_lock'))
    x = x + move:GetWidth()
    local move_toggle = title_gb:CreateOrGetControl('picture', "move_toggle", x, 80, 60, 25);
    AUTO_CAST(move_toggle)
    local icon_name = "test_com_ability_on"
    if g.muteki_settings.etc.lock == 1 then
        icon_name = "test_com_ability_off"
    end
    move_toggle:SetImage(icon_name)
    move_toggle:SetEnableStretch(1)
    move_toggle:EnableHitTest(1)
    move_toggle:SetTextTooltip(muteki_trans("lock_notice"))
    move_toggle:SetEventScript(ui.LBUTTONUP, "Muteki_change_settings")
    x = x + move_toggle:GetWidth() + 10
    local rotate = title_gb:CreateOrGetControl('richtext', 'rotate', x, 85, 10, 30)
    AUTO_CAST(rotate)
    rotate:SetText(muteki_trans("icon_rotate"))
    x = x + rotate:GetWidth()
    local rotate_toggle = title_gb:CreateOrGetControl('picture', "rotate_toggle", x, 80, 60, 25);
    AUTO_CAST(rotate_toggle)
    local icon_name = "test_com_ability_on"
    if g.muteki_settings.etc.rotate ~= 1 then
        icon_name = "test_com_ability_off"
    end
    rotate_toggle:SetImage(icon_name)
    rotate_toggle:SetEnableStretch(1)
    rotate_toggle:EnableHitTest(1)
    rotate_toggle:SetEventScript(ui.LBUTTONUP, "Muteki_change_settings")
    local add = title_gb:CreateOrGetControl("button", "add", 530, 80, 50, 30)
    AUTO_CAST(add)
    add:SetSkinName("test_cardtext_btn")
    add:SetText("{ol}" .. "Add")
    add:SetTextTooltip(muteki_trans("add_new"))
    add:SetEventScript(ui.LBUTTONUP, "Muteki_buff_list_open")
    local close = title_gb:CreateOrGetControl("button", "close", 0, 0, 25, 25)
    AUTO_CAST(close)
    close:SetImage("testclose_button")
    close:SetGravity(ui.RIGHT, ui.TOP)
    close:SetEventScript(ui.LBUTTONUP, "Muteki_setting_frame_close")
    local gb = settings:CreateOrGetControl("groupbox", "gb", 10, 110, 580, settings:GetHeight() - 120)
    AUTO_CAST(gb)
    gb:SetSkinName("bg")
    gb:RemoveAllChild()
    Muteki_setting_gbox_init(settings, gb)
    settings:ShowWindow(1)
    -- ESC は × ボタンと同じ閉じ方にする(設定を閉じたらバフ/スキル一覧も畳む)。
    -- Muteki_setting_frame_close は押されたコントロールから GetTopParentFrame で辿る作りなので、
    -- フレームしか手元に無いここからは呼べない。同じ後始末をここで行う。
    -- この関数はバフ/スキルを足すたびに呼び直されるので esc_register_keep を使う。
    -- 積み直すと、開いたままのバフ/スキル一覧より設定画面が手前になり、
    -- ESC 1 回で 3 枚まとめて消える。
    local settings_name = addon_name_lower .. "muteki_settings"
    g.esc_register_keep(settings_name, function()
        ui.DestroyFrame(settings_name)
        ui.DestroyFrame(addon_name_lower .. "muteki_buff_list")
        ui.DestroyFrame(addon_name_lower .. "muteki_skill_list")
        ui.DestroyFrame(addon_name_lower .. "muteki_effect_list")
    end)
end

function Muteki_setting_gbox_init(settings, gb)
    local sorted_buff_list = {}
    if g.muteki_settings.buff_list and type(g.muteki_settings.buff_list) == "table" then
        for buff_id_str, buff_data in pairs(g.muteki_settings.buff_list) do
            table.insert(sorted_buff_list, {
                buff_id = tonumber(buff_id_str),
                data = buff_data
            })
        end
    end
    table.sort(sorted_buff_list, function(a, b)
        return a.buff_id < b.buff_id
    end)
    local index = 1
    for i, entry in ipairs(sorted_buff_list) do
        index = index + 1
        local buff_id = entry.buff_id
        local buff_data = entry.data
        local buff_cls = GetClassByType('Buff', buff_id)
        local list = gb:CreateOrGetControl('groupbox', 'list' .. buff_id, 5, 5 + 175 * (i - 1), 555, 175)
        list:SetSkinName("market_listbase")
        local buff_pic = list:CreateOrGetControl('picture', 'buff_pic', 95, 10, 30, 30)
        AUTO_CAST(buff_pic)
        buff_pic:SetEnableStretch(1)
        if buff_cls and buff_cls.Icon then
            local icon_name = 'icon_' .. buff_cls.Icon
            if buff_cls.Icon == "None" then
                icon_name = "icon_item_nothing"
            end
            buff_pic:SetImage(icon_name)
            buff_pic:SetTextTooltip(muteki_trans('delete_notice'))
            buff_pic:SetEventScript(ui.RBUTTONUP, 'Muteki_delete_buff')
            buff_pic:SetEventScriptArgString(ui.RBUTTONUP, buff_cls.Name)
            buff_pic:SetEventScriptArgNumber(ui.RBUTTONUP, buff_id)
            local buff_name = list:CreateOrGetControl('richtext', 'buff_name', 130, 15, 60, 30)
            AUTO_CAST(buff_name)
            buff_name:SetText('{#000000}' .. buff_cls.Name)
            buff_name:SetTooltipType('buff')
            buff_name:SetTooltipArg(buff_name, buff_id, 0)
            local buff_edit = list:CreateOrGetControl('edit', 'buff_edit', 10, 10, 80, 30)
            AUTO_CAST(buff_edit)
            buff_edit:SetNumberMode(1)
            buff_edit:SetFontName("white_16_ol")
            buff_edit:SetText(buff_cls.ClassID)
            buff_edit:SetTextAlign("center", "center")
            buff_edit:SetTextTooltip(muteki_trans('function_notice'))
            buff_edit:SetTypingScp("Muteki_add_buff")
            buff_edit:SetEventScript(ui.ENTERKEY, 'Muteki_add_buff')
            buff_edit:SetEventScriptArgString(ui.ENTERKEY, buff_id)
        end
        local circle = list:CreateOrGetControl('checkbox', 'circle', 10, 45, 200, 25)
        AUTO_CAST(circle)
        local circle_icon = buff_data.circle_icon
        circle:SetCheck(circle_icon)
        circle:SetText(muteki_trans('icon_mode'))
        circle:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
        circle:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        local not_notify = list:CreateOrGetControl('checkbox', 'not_notify', 10, 70, 200, 25)
        AUTO_CAST(not_notify)
        not_notify:SetCheck(buff_data.not_notify[g.cid])
        not_notify:SetText(muteki_trans('not_notify'))
        not_notify:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
        not_notify:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        local pt_chat = list:CreateOrGetControl('checkbox', 'pt_chat', 10, 95, 200, 25)
        AUTO_CAST(pt_chat)
        pt_chat:SetCheck(buff_data.pt_chat)
        pt_chat:SetText(muteki_trans('pt_chat'))
        pt_chat:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
        pt_chat:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        local nico_chat = list:CreateOrGetControl('checkbox', 'nico_chat', 10, 120, 200, 25)
        AUTO_CAST(nico_chat)
        nico_chat:SetCheck(buff_data.nico_chat)
        nico_chat:SetText(muteki_trans('nico_chat'))
        nico_chat:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
        nico_chat:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        local effect = list:CreateOrGetControl('checkbox', 'effect', 270, 70, 200, 25)
        AUTO_CAST(effect)
        effect:SetCheck(buff_data.effect_check)
        effect:SetText(muteki_trans('with_effect'))
        effect:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
        effect:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        local effect_set = list:CreateOrGetControl('button', 'effect_set', 470, 68, 75, 28)
        AUTO_CAST(effect_set)
        effect_set:SetSkinName("test_cardtext_btn")
        effect_set:SetText("{s13}" .. muteki_trans('effect_setting'))
        effect_set:SetTextTooltip(muteki_trans('effect_setting_notice'))
        effect_set:SetEventScript(ui.LBUTTONUP, "Muteki_effect_list_open")
        effect_set:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
        local color_pic = list:CreateOrGetControl('picture', 'color_pic', 510, 10, 30, 25)
        AUTO_CAST(color_pic)
        color_pic:SetEnableStretch(1)
        color_pic:SetImage("chat_color")
        color_pic:SetColorTone(buff_data.color or g.muteki_default_color)
        color_pic:SetTextTooltip(muteki_trans('color_tone'))
        local color_tbl = {'FFFFFF00', -- [1] 黄色
        'FFFFD700', -- [2] ゴールド
        'FFFF4500', -- [3] オレンジ
        'FF00FF00', -- [4] ライムグリーン
        'FF008000', -- [5] 緑
        'FF00BFFF', -- [6] スカイブルー
        'FF0000FF', -- [7] 青
        'FF800080', -- [8] 紫
        "FFFF1493", -- [9] ピンク
        "FFFF0000" -- [10] 赤
        }
        local color_box = list:CreateOrGetControl('groupbox', "color_box", 315, 45, 220, 25);
        AUTO_CAST(color_box)
        for i = 1, #color_tbl do
            local color_value = color_tbl[i]
            local color = color_box:CreateOrGetControl("picture", "color_" .. i, 20 * i, 0, 20, 25);
            AUTO_CAST(color)
            color:SetImage("chat_color")
            color:SetColorTone(color_value)
            color:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
            color:SetEventScriptArgString(ui.LBUTTONUP, color_value)
            color:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
        end
        local color_edit = list:CreateOrGetControl('edit', 'color_edit', 405, 10, 100, 30)
        AUTO_CAST(color_edit)
        color_edit:SetFontName("white_16_ol")
        color_edit:SetText("{ol}" .. buff_data.color or g.muteki_default_color)
        color_edit:SetTextAlign("center", "center")
        color_edit:SetTextTooltip(muteki_trans('color_notice'))
        color_edit:SetNumberMode(0)
        color_edit:SetEventScript(ui.ENTERKEY, 'Muteki_setting_change')
        color_edit:SetEventScriptArgString(ui.ENTERKEY, buff_data.color or g.muteki_default_color)
        color_edit:SetEventScriptArgNumber(ui.ENTERKEY, buff_id)
        if buff_cls.OverBuff > 1 then
            local count_display = list:CreateOrGetControl('checkbox', 'count_display', 270, 95, 200, 25)
            AUTO_CAST(count_display)
            count_display:SetCheck(buff_data.count_display)
            count_display:SetText(muteki_trans('count_display'))
            count_display:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
            count_display:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
        end
        local x = 0
        local xx = 0
        local time_edit = list:CreateOrGetControl('edit', 'time_edit', 10, 145, 80, 25)
        AUTO_CAST(time_edit)
        time_edit:SetFontName("white_16_ol")
        time_edit:SetTextAlign("center", "center")
        time_edit:SetNumberMode(1)
        local debuff_time = ""
        local buff_time = ""
        local current_buff_list = g.muteki_settings.buff_list[tostring(buff_id)]
        if buff_cls.Group1 == "Debuff" or buff_cls.Group1 == "Deuff" then
            if current_buff_list and current_buff_list.debuffs and current_buff_list.debuffs[g.cid] then
                local d_manage = current_buff_list.debuffs[g.cid]
                if d_manage.debuff_time and d_manage.debuff_time > 0 then
                    debuff_time = d_manage.debuff_time
                end
            end
            time_edit:SetText("{ol}" .. (debuff_time or ""))
            time_edit:SetTextTooltip(muteki_trans('debuff_notice'))
            time_edit:SetUserValue("SWITCH", "debuff")
            time_edit:SetUserValue("BUFF_ID", buff_id)
            time_edit:SetTypingScp("Muteki_setting_change")
            time_edit:SetEventScript(ui.ENTERKEY, 'Muteki_setting_change')
            time_edit:SetEventScriptArgString(ui.ENTERKEY, buff_id)
            x = x + time_edit:GetWidth() + 15
            local time = list:CreateOrGetControl('richtext', 'time', x, 147, 100, 25)
            AUTO_CAST(time)
            time:SetText(muteki_trans('debuff_time'))
            x = x + time:GetWidth() + 10
        else
            if current_buff_list and current_buff_list.buffs and current_buff_list.buffs[g.cid] then
                local b_manage = current_buff_list.buffs[g.cid]
                if b_manage.buff_time and b_manage.buff_time > 0 then
                    buff_time = b_manage.buff_time
                end
            end
            time_edit:SetText("{ol}" .. (buff_time or ""))
            time_edit:SetTextTooltip(muteki_trans('buff_notice_cid'))
            time_edit:SetUserValue("SWITCH", "buff")
            time_edit:SetUserValue("BUFF_ID", buff_id)
            time_edit:SetTypingScp("Muteki_setting_change")
            time_edit:SetEventScript(ui.ENTERKEY, 'Muteki_setting_change')
            time_edit:SetEventScriptArgString(ui.ENTERKEY, buff_id)
            xx = xx + time_edit:GetWidth() + 15
            local time = list:CreateOrGetControl('richtext', 'time', xx, 147, 100, 25)
            AUTO_CAST(time)
            time:SetText(muteki_trans('buff_time_cid'))
            xx = xx + time:GetWidth() + 10
        end
        x = x >= xx and x or xx
        if buff_time ~= "" or debuff_time ~= "" then
            local skill_edit = list:CreateOrGetControl('edit', 'skill_edit', x, 145, 80, 25)
            AUTO_CAST(skill_edit)
            skill_edit:SetFontName("white_16_ol")
            local skill_id = ""
            if current_buff_list then
                if current_buff_list.buffs and current_buff_list.buffs[g.cid] then
                    local bm = current_buff_list.buffs[g.cid]
                    if bm.skill_id and bm.skill_id > 0 then
                        skill_id = bm.skill_id
                    end
                end
                if current_buff_list.debuffs and current_buff_list.debuffs[g.cid] then
                    local dm = current_buff_list.debuffs[g.cid]
                    if dm.skill_id and dm.skill_id > 0 then
                        skill_id = dm.skill_id
                    end
                end
            end
            skill_edit:SetTextTooltip(muteki_trans('skill_notice'))
            skill_edit:SetTextAlign("center", "center")
            skill_edit:SetNumberMode(1)
            skill_edit:SetText("{ol}" .. skill_id)
            skill_edit:SetUserValue("SWITCH", time_edit:GetUserValue("SWITCH"))
            skill_edit:SetUserValue("BUFF_ID", buff_id)
            skill_edit:SetEventScript(ui.ENTERKEY, 'Muteki_setting_change')
            skill_edit:SetEventScriptArgString(ui.ENTERKEY, buff_id)
            skill_edit:SetTypingScp("Muteki_setting_change")
            x = x + skill_edit:GetWidth() + 5
            local skill_text = list:CreateOrGetControl('richtext', 'skill_text', x, 147, 100, 25)
            AUTO_CAST(skill_text)
            skill_text:SetText(muteki_trans('skill_text'))
            x = x + skill_text:GetWidth() + 5
            local add = list:CreateOrGetControl("button", "add", x, 140, 40, 30)
            AUTO_CAST(add)
            add:SetSkinName("test_cardtext_btn")
            add:SetText("{ol}{s13}" .. "Add")
            add:SetTextTooltip(muteki_trans("add_new_skill"))
            add:SetEventScript(ui.LBUTTONUP, "Muteki_skill_list_open")
            add:SetEventScriptArgNumber(ui.LBUTTONUP, tonumber(buff_id))
        end
        local end_sound = list:CreateOrGetControl('checkbox', 'end_sound', 270, 120, 200, 25)
        AUTO_CAST(end_sound)
        end_sound:SetCheck(buff_data.end_sound)
        end_sound:SetText(muteki_trans('end_sound'))
        end_sound:SetEventScript(ui.LBUTTONUP, 'Muteki_setting_change')
        end_sound:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
    end
    local list = gb:CreateOrGetControl('groupbox', 'list' .. index, 5, 5 + 175 * (index - 1), 555, 175)
    list:SetSkinName("market_listbase")
    local buff_edit = list:CreateOrGetControl('edit', 'buff_edit', 10, 10, 80, 30)
    AUTO_CAST(buff_edit)
    buff_edit:SetNumberMode(1)
    buff_edit:SetFontName("white_16_ol")
    buff_edit:SetTextAlign("center", "center")
    buff_edit:SetTextTooltip(muteki_trans('function_notice'))
    buff_edit:SetEventScript(ui.ENTERKEY, 'Muteki_add_buff')
    buff_edit:SetTextTooltip(muteki_trans('function_notice'))
    buff_edit:SetTypingScp("Muteki_add_buff")
    for i, entry in ipairs(sorted_buff_list) do
        local buff_id = entry.buff_id
        if g.muteki_cur_pos and tostring(buff_id) == g.muteki_cur_pos then
            gb:SetScrollPos(155 * (i - 3))
            local list = GET_CHILD(gb, "list" .. buff_id)
            list:SetSkinName("test_skin_01") -- monster_card_list
            g.muteki_cur_pos = nil
        end
    end
end

function Muteki_change_settings_edit(ctrl)
    local config_map = {
        buff_time_edit = {
            key = "hide_time",
            default = 300,
            msg_key = "hide_sec"
        },
        layer_edit = {
            key = "layer_lv",
            default = 80,
            msg_key = "layer_notice"
        }
    }
    local config = config_map[ctrl:GetName()]
    if not config then
        return
    end
    local val = tonumber(ctrl:GetText())
    if val then
        g.muteki_settings.etc[config.key] = val
        ui.SysMsg(string.format(muteki_trans(config.msg_key), val))
        Muteki_save_settings()
        Muteki_setting_frame_init()
        Muteki_buff_frame_init()
        Muteki_refresh_active_buffs()
    else
        g.muteki_settings.etc[config.key] = config.default
    end
    return 0
end

function Muteki_change_settings(frame, ctrl, str, num)
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "buff_time_edit" or ctrl_name == "layer_edit" then
        ctrl:RunUpdateScript("Muteki_change_settings_edit", 1.0)
        return
    elseif ctrl_name == "mode_toggle" then
        if g.muteki_settings.etc.mode == "fixed" then
            g.muteki_settings.etc.mode = "trace"
        else
            g.muteki_settings.etc.mode = "fixed"
        end
    elseif ctrl_name == "move_toggle" then
        if g.muteki_settings.etc.lock == 1 then
            g.muteki_settings.etc.lock = 0
        else
            g.muteki_settings.etc.lock = 1
        end
    elseif ctrl_name == "rotate_toggle" then
        if g.muteki_settings.etc.rotate == 1 then
            g.muteki_settings.etc.rotate = 0
        else
            g.muteki_settings.etc.rotate = 1
        end
    end
    Muteki_save_settings()
    Muteki_setting_frame_init()
    Muteki_buff_frame_init()
    Muteki_refresh_active_buffs()
end

function Muteki_setting_change_edit(ctrl)
    local switch = ctrl:GetUserValue("SWITCH")
    local buff_id_str = ctrl:GetUserValue("BUFF_ID")
    local ctrl_name = ctrl:GetName()
    local input_val = tonumber(ctrl:GetText())
    local type_key = (switch == "debuff") and "debuffs" or "buffs"
    local setting_entry = g.muteki_settings.buff_list[buff_id_str]
    if not setting_entry[type_key][g.cid] then
        setting_entry[type_key][g.cid] = {}
    end
    local target_data = setting_entry[type_key][g.cid]
    if ctrl_name == "skill_edit" then
        if input_val then
            local skill_cls = GetClassByType("Skill", input_val)
            if skill_cls then
                target_data.skill_id = input_val
                ui.SysMsg(string.format(muteki_trans("skill_set"), skill_cls and skill_cls.Name or input_val))
            else
                ctrl:SetText("")
                target_data.skill_id = 0
            end
        else
            ctrl:SetText("")
            target_data.skill_id = 0
        end
    else
        local time_key = (switch == "debuff") and "debuff_time" or "buff_time"
        target_data[time_key] = input_val or 0
        if not input_val then
            ctrl:SetText("")
        end
        ui.SysMsg(string.format(muteki_trans("debuff_manage_set"), target_data[time_key]))
    end
    Muteki_skill_list()
    Muteki_setting_frame_init()
    Muteki_save_settings()
    Muteki_refresh_active_buffs()
    return 0
end

function Muteki_setting_change(frame, ctrl, arg_str, arg_num)
    local ctrl_name = ctrl:GetName()
    local buff_id = arg_num
    local buff_id_str = tostring(buff_id)
    local not_notify = {}
    if ctrl_name == "circle" then
        g.muteki_settings.buff_list[arg_str].circle_icon = ctrl:IsChecked()
    elseif ctrl_name == "not_notify" then
        g.muteki_settings.buff_list[arg_str].not_notify[g.cid] = ctrl:IsChecked()
    elseif ctrl_name == "pt_chat" then
        g.muteki_settings.buff_list[arg_str].pt_chat = ctrl:IsChecked()
    elseif ctrl_name == "nico_chat" then
        g.muteki_settings.buff_list[arg_str].nico_chat = ctrl:IsChecked()
    elseif ctrl_name == "effect" then
        g.muteki_settings.buff_list[arg_str].effect_check = ctrl:IsChecked()
    elseif ctrl_name == "count_display" then
        g.muteki_settings.buff_list[arg_str].count_display = ctrl:IsChecked()
    elseif ctrl_name == "end_sound" then
        g.muteki_settings.buff_list[arg_str].end_sound = ctrl:IsChecked()
    elseif ctrl_name == "color_edit" then
        local color_text = ctrl:GetText()
        if string.len(color_text) ~= 8 then
            ctrl:SetText(g.muteki_settings.buff_list[buff_id_str].color)
            ui.SysMsg(muteki_trans("color_notice"))
            return
        end
        g.muteki_settings.buff_list[buff_id_str].color = color_text
    elseif string.find(ctrl_name, "color_") then
        g.muteki_settings.buff_list[buff_id_str].color = arg_str
    elseif ctrl_name == "time_edit" or ctrl_name == "skill_edit" then
        ctrl:RunUpdateScript("Muteki_setting_change_edit", 1.0)
        return
    end
    Muteki_setting_frame_init()
    Muteki_save_settings()
    Muteki_refresh_active_buffs()
end

function Muteki_add_buff_msg(frame, ctrl, cls_name, buff_id)
    local yes_scp = string.format("Muteki_add_buff('','%s','%s','')", ctrl:GetName(), buff_id)
    local msg = string.format(muteki_trans('add_check'), cls_name)
    ui.MsgBox(msg, yes_scp, "None")
end

function Muteki_add_buff_edit(ctrl)
    local ctrl_name = ctrl:GetName()
    local buff_id_str = ctrl:GetText()
    local buff_id = tonumber(buff_id_str)
    if buff_id and (ctrl_name == "buff_edit" or ctrl_name == "id_edit") then
        local buff_cls = GetClassByType("Buff", buff_id)
        if buff_cls then
            g.muteki_settings.buff_list[tostring(buff_id)] = {
                circle_icon = 0,
                effect_check = 0,
                not_notify = {},
                count_display = 0,
                pt_chat = 0,
                nico_chat = 0,
                end_sound = "None",
                color = "FFCCCC22",
                buffs = {},
                debuffs = {}
            }
            ui.SysMsg(string.format(muteki_trans("add_buff"), buff_cls.Name))
            Muteki_save_settings()
            g.muteki_cur_pos = ctrl:GetY()
            Muteki_setting_frame_init()
        end
    end
    if ctrl_name == "id_edit" then
        ctrl:SetText("")
    end
    Muteki_refresh_active_buffs()
    return 0
end

function Muteki_add_buff(frame, ctrl, buff_id_str, num)
    local ctrl_name = ""
    if type(ctrl) == "string" then
        ctrl_name = ctrl
    else
        ctrl_name = ctrl:GetName()
    end
    local buff_id_process = nil
    if string.find(ctrl_name, "buff_set") then
        buff_id_process = buff_id_str
    elseif ctrl_name == "buff_edit" then
        ctrl:RunUpdateScript("Muteki_add_buff_edit", 1.0)
        return
    elseif ctrl_name == "id_edit" then
        ctrl:RunUpdateScript("Muteki_add_buff_edit", 1.0)
        return
    elseif string.find(ctrl_name, "slot") then
        buff_id_process = buff_id_str
    end
    if buff_id_process and buff_id_process ~= "" then
        local buff_id_num = tonumber(buff_id_process)
        local buff_cls = GetClassByType("Buff", buff_id_num)
        if buff_cls then
            g.muteki_settings.buff_list[buff_id_process] = {
                ["circle_icon"] = 0,
                ["effect_check"] = 0,
                ["not_notify"] = {},
                ["count_display"] = 0,
                ["pt_chat"] = 0,
                ["nico_chat"] = 0,
                ["end_sound"] = "None",
                ["color"] = "FFCCCC22",
                ["buffs"] = {},
                ["debuffs"] = {}
            }
            ui.SysMsg(string.format(muteki_trans("add_buff"), buff_cls.Name))
        else
            return
        end
    end
    Muteki_save_settings()
    if not string.find(ctrl_name, "slot") then
        g.muteki_cur_pos = buff_id_process
        Muteki_setting_frame_init()
    end
    Muteki_refresh_active_buffs()
end

function Muteki_delete_buff(frame, ctrl, buff_name, buff_id)
    local ctrl_name = ctrl:GetName()
    if ctrl_name == "buff_pic" then
        g.muteki_settings.buff_list[tostring(buff_id)] = nil
        ui.SysMsg(string.format(muteki_trans("delete_buff"), buff_name))
    end
    Muteki_save_settings()
    Muteki_setting_frame_init()
    Muteki_BUFF_ON_MSG("", "BUFF_REMOVE", "dummy", buff_id)
end

function Muteki_buff_list_open(frame, ctrl, ctrl_text, num)
    local buff_list_frame_name = addon_name_lower .. "muteki_buff_list"
    local buff_list = ui.GetFrame(addon_name_lower .. "muteki_buff_list")
    if not buff_list then
        buff_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "muteki_buff_list", 0, 0, 10, 10)
        AUTO_CAST(buff_list)
        g.block_click_through(buff_list)
        buff_list:SetSkinName("test_frame_low")
        buff_list:Resize(500, 1005)
        buff_list:SetPos(610, 30)
        buff_list:SetLayerLevel(999)
        local id_edit = buff_list:CreateOrGetControl('edit', 'id_edit', 20, 15, 80, 30)
        AUTO_CAST(id_edit)
        id_edit:SetNumberMode(1)
        id_edit:SetFontName("white_16_ol")
        id_edit:SetTextAlign("center", "center")
        id_edit:SetText("")
        id_edit:SetEventScript(ui.ENTERKEY, 'Muteki_add_buff')
        id_edit:SetTextTooltip(muteki_trans("add_buffid"))
        local search_edit = buff_list:CreateOrGetControl("edit", "search_edit", id_edit:GetWidth() + 40, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Muteki_buff_list_search")
        g.setup_incremental_search(search_edit, "Muteki_buff_list_search")
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Muteki_buff_list_search")
        local close_button = buff_list:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
        AUTO_CAST(close_button)
        close_button:SetImage("testclose_button")
        close_button:SetGravity(ui.RIGHT, ui.TOP)
        close_button:SetEventScript(ui.LBUTTONUP, "Muteki_buff_list_close")
    end
    local buff_list_gb = buff_list:CreateOrGetControl("groupbox", "buff_list_gb", 10, 50, 480,
        buff_list:GetHeight() - 60)
    AUTO_CAST(buff_list_gb)
    buff_list_gb:SetSkinName("bg")
    buff_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Buff")
    local y = 0
    for i = 0, count - 1 do
        local buff_cls = GetClassByIndexFromList(cls_list, i)
        if buff_cls then
            local buff_id = buff_cls.ClassID
            local buff_name = dictionary.ReplaceDicIDInCompStr(buff_cls.Name)
            if ctrl_text == "" or (ctrl_text ~= "" and string.find(buff_name, ctrl_text)) then
                local buff_slot = buff_list_gb:CreateOrGetControl('slot', 'buffslot' .. i, 10, y + 5, 30, 30)
                AUTO_CAST(buff_slot)
                local image_name = GET_BUFF_ICON_NAME(buff_cls)
                if image_name == "icon_None" then
                    image_name = "icon_item_nothing"
                end
                if buff_name ~= "None" then
                    SET_SLOT_IMG(buff_slot, image_name)
                    local icon = CreateIcon(buff_slot)
                    AUTO_CAST(icon)
                    icon:SetTooltipType('buff')
                    icon:SetTooltipArg(buff_name, buff_id, 0)
                    local buff_set = buff_list_gb:CreateOrGetControl('button', 'buff_set' .. buff_id, 45, y + 5, 40, 30)
                    AUTO_CAST(buff_set)
                    buff_set:SetText("{ol}Add")
                    buff_set:SetSkinName("test_cardtext_btn")
                    buff_set:SetTextTooltip(muteki_trans("add_new"))
                    buff_set:SetEventScript(ui.LBUTTONUP, "Muteki_add_buff")
                    buff_set:SetEventScriptArgString(ui.LBUTTONUP, buff_id)
                    local buff_text = buff_list_gb:CreateOrGetControl('richtext', 'buff_text' .. buff_id, 90, y + 10,
                        200, 30)
                    AUTO_CAST(buff_text)
                    buff_text:SetText("{ol}" .. buff_id .. " : " .. buff_name)
                    buff_text:AdjustFontSizeByWidth(380)
                    y = y + 35
                end
            end
        end
    end
    buff_list:ShowWindow(1)
    g.esc_register_destroy(addon_name_lower .. "muteki_buff_list")
end

function Muteki_buff_list_search(frame, ctrl, str, num)
    local search_edit = GET_CHILD_RECURSIVELY(frame, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        Muteki_buff_list_open(frame, ctrl, ctrl_text)
    else
        Muteki_buff_list_open(frame, ctrl, "")
    end
end

function Muteki_buff_list_close(frame, ctrl, str, num)
    ui.DestroyFrame(frame:GetName())
end

function Muteki_skill_list_open(frame, add, ctrl_text, buff_id)
    local skill_list = ui.GetFrame(addon_name_lower .. "muteki_skill_list")
    if not skill_list then
        skill_list = ui.CreateNewFrame("notice_on_pc", addon_name_lower .. "muteki_skill_list", 0, 0, 10, 10)
        AUTO_CAST(skill_list)
        g.block_click_through(skill_list)
        skill_list:SetSkinName("test_frame_low")
        skill_list:Resize(500, 1005)
        skill_list:SetPos(610, 30)
        skill_list:SetLayerLevel(999)
        local title_text = skill_list:CreateOrGetControl('richtext', 'itle_text', 15, 15, 10, 30)
        AUTO_CAST(title_text)
        title_text:SetText("{#000000}{s20}Skill List")
        local search_edit =
            skill_list:CreateOrGetControl("edit", "search_edit", title_text:GetWidth() + 30, 10, 305, 38)
        AUTO_CAST(search_edit)
        search_edit:SetFontName("white_18_ol")
        search_edit:SetTextAlign("left", "center")
        search_edit:SetSkinName("inventory_serch")
        search_edit:SetEventScript(ui.ENTERKEY, "Muteki_skill_list_search")
        search_edit:SetEventScriptArgNumber(ui.ENTERKEY, buff_id)
        g.setup_incremental_search(search_edit, "Muteki_skill_list_search", buff_id)
        local search_btn = search_edit:CreateOrGetControl("button", "search_btn", 0, 0, 40, 38)
        AUTO_CAST(search_btn)
        search_btn:SetImage("inven_s")
        search_btn:SetGravity(ui.RIGHT, ui.TOP)
        search_btn:SetEventScript(ui.LBUTTONUP, "Muteki_skill_list_search")
        local close_button = skill_list:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
        AUTO_CAST(close_button)
        close_button:SetImage("testclose_button")
        close_button:SetGravity(ui.RIGHT, ui.TOP)
        close_button:SetEventScript(ui.LBUTTONUP, "Muteki_skill_list_close")
    end
    local skill_list_gb = skill_list:CreateOrGetControl("groupbox", "skill_list_gb", 10, 50, 480,
        skill_list:GetHeight() - 60)
    AUTO_CAST(skill_list_gb)
    skill_list_gb:SetSkinName("bg")
    skill_list_gb:RemoveAllChild()
    local cls_list, count = GetClassList("Skill")
    local y = 0
    for i = 0, count - 1 do
        local skill_cls = GetClassByIndexFromList(cls_list, i)
        if skill_cls then
            local skill_id = skill_cls.ClassID
            local skill_cls_name = skill_cls.ClassName
            local skill_engname = skill_cls.EngName
            local skill_caption = skill_cls.Caption
            local skill_name = dictionary.ReplaceDicIDInCompStr(skill_cls.Name)
            if ctrl_text == "" or (ctrl_text ~= "" and string.find(skill_name, ctrl_text)) then
                local skill_slot = skill_list_gb:CreateOrGetControl('slot', 'skill_slot' .. i, 10, y + 5, 30, 30)
                AUTO_CAST(skill_slot)
                local image_name = "icon_" .. skill_cls.Icon
                if skill_id > 10000 then
                    if not string.find(skill_cls_name, "^Mon_") and not string.find(skill_engname, "plzInputEngName") and
                        not string.find(skill_name, "_") and not string.find(skill_name, "TEST") then
                        if ctrl_text == "" or (ctrl_text ~= "" and string.find(skill_name, ctrl_text)) then
                            SET_SLOT_IMG(skill_slot, image_name)
                            local icon = CreateIcon(skill_slot)
                            AUTO_CAST(icon)
                            SET_SKILL_TOOLTIP_BY_TYPE(icon, skill_id)
                            local skill_set = skill_list_gb:CreateOrGetControl('button', 'skill_set' .. skill_id, 45,
                                y + 5, 40, 30)
                            AUTO_CAST(skill_set)
                            skill_set:SetText("{ol}Add")
                            skill_set:SetSkinName("test_cardtext_btn")
                            skill_set:SetTextTooltip(muteki_trans("add_new_skill"))
                            skill_set:SetEventScript(ui.LBUTTONUP, "Muteki_add_skill")
                            skill_set:SetEventScriptArgNumber(ui.LBUTTONUP, skill_id)
                            skill_set:SetEventScriptArgString(ui.LBUTTONUP, tostring(buff_id))
                            local skill_text = skill_list_gb:CreateOrGetControl('richtext', 'skill_text' .. skill_id,
                                90, y + 10, 200, 30)
                            AUTO_CAST(skill_text)
                            skill_text:SetText("{ol}" .. skill_id .. " : " .. skill_name)
                            skill_text:AdjustFontSizeByWidth(380)
                            y = y + 35
                        end
                    end
                end
            end
        end

    end
    skill_list:ShowWindow(1)
    g.esc_register_destroy(addon_name_lower .. "muteki_skill_list")
end

function Muteki_skill_list_search(frame, ctrl, str, buff_id)
    local search_edit = GET_CHILD_RECURSIVELY(frame, "search_edit")
    local ctrl_text = search_edit:GetText()
    if ctrl_text ~= "" then
        Muteki_skill_list_open(frame, ctrl, ctrl_text, buff_id)
    else
        Muteki_skill_list_open(frame, ctrl, "", buff_id)
    end
end

function Muteki_skill_list_close(frame, ctrl, str, num)
    ui.DestroyFrame(frame:GetName())
end

function Muteki_add_skill(frame, ctrl, buff_id_str, skill_id)
    local ctrl_name = ctrl:GetName()
    local settings = ui.GetFrame(addon_name_lower .. "muteki_settings")
    local list = GET_CHILD_RECURSIVELY(settings, 'list' .. buff_id_str)
    local skill_edit = GET_CHILD(list, "skill_edit")
    skill_edit:SetText(skill_id)
    local switch = skill_edit:GetUserValue("SWITCH")
    Muteki_setting_change_edit(skill_edit)
end

-- エフェクト設定の窓の 1 段ぶん（開始時 / 重複が最大になったとき）を組み立てる。
-- 一覧は「選ぶための道具」で、いま何が設定されているかは下の入力欄が正本。
function Muteki_effect_row(effect_frame, kind, y, buff_id, buff_data)
    local mode = Muteki_effect_mode(buff_data, kind)
    -- 見出しそのものを ON/OFF のチェックにする（開始時は設定画面の「エフェクト付与」と同じ値）
    -- 「重複が最大になったとき」は長いので、チェックの幅は日本語が収まる 230 を取る
    local use_check = effect_frame:CreateOrGetControl('checkbox', kind .. '_use', 15, y, 230, 25)
    AUTO_CAST(use_check)
    use_check:SetText(muteki_trans(kind == "over" and 'effect_over' or 'effect_start'))
    use_check:SetCheck(Muteki_effect_enabled(buff_data, kind) and 1 or 0)
    use_check:SetTextTooltip(muteki_trans('effect_use_notice'))
    use_check:SetEventScript(ui.LBUTTONUP, "Muteki_effect_use_toggle")
    use_check:SetEventScriptArgString(ui.LBUTTONUP, kind)
    use_check:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
    -- 種類。通常エフェクトと UI エフェクトでは**選べる名前がまるで別**なので、
    -- ここで選んだ側の候補だけを下の一覧に出す。設定も種類ごとに別々に残る。
    local type_list = effect_frame:CreateOrGetControl('droplist', kind .. '_type', 250, y + 2, 190, 24)
    AUTO_CAST(type_list)
    type_list:SetSkinName('droplist_normal')
    type_list:EnableHitTest(1)
    type_list:SetTextAlign("center", "center")
    type_list:ClearItems()
    local type_order = {"actor", "ui"}
    for i, type_mode in ipairs(type_order) do
        type_list:AddItem(i - 1, muteki_trans('effect_type_' .. type_mode), 0,
            string.format("Muteki_effect_type_select(%d, '%s', '%s')", buff_id, kind, type_mode))
        if type_mode == mode then
            type_list:SelectItem(i - 1)
        end
    end
    local drop_list = effect_frame:CreateOrGetControl('droplist', kind .. '_droplist', 15, y + 30, 320, 25)
    AUTO_CAST(drop_list)
    drop_list:SetSkinName('droplist_normal')
    drop_list:EnableHitTest(1)
    drop_list:SetTextAlign("center", "center")
    Muteki_effect_fill_presets(effect_frame, kind, buff_id, mode == "ui")
    local test_btn = effect_frame:CreateOrGetControl('button', kind .. '_test', 350, y + 28, 90, 30)
    AUTO_CAST(test_btn)
    test_btn:SetSkinName("test_cardtext_btn")
    test_btn:SetText("{s13}" .. muteki_trans('effect_test'))
    test_btn:SetTextTooltip(muteki_trans('effect_test_notice'))
    test_btn:SetEventScript(ui.LBUTTONUP, "Muteki_effect_test")
    test_btn:SetEventScriptArgString(ui.LBUTTONUP, kind)
    test_btn:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
    local name_text = effect_frame:CreateOrGetControl('richtext', kind .. '_name', 15, y + 62, 10, 25)
    AUTO_CAST(name_text)
    name_text:SetText(muteki_trans('effect_name'))
    local name_edit = effect_frame:CreateOrGetControl('edit', kind .. '_edit', 120, y + 60, 255, 25)
    AUTO_CAST(name_edit)
    name_edit:SetFontName("white_16_ol")
    name_edit:SetTextAlign("left", "center")
    name_edit:SetText("{ol}" .. Muteki_effect_name(buff_data, kind))
    name_edit:SetTextTooltip(muteki_trans('effect_name_notice'))
    name_edit:SetUserValue("KIND", kind)
    name_edit:SetEventScript(ui.ENTERKEY, "Muteki_effect_edit")
    name_edit:SetEventScriptArgNumber(ui.ENTERKEY, buff_id)
    local scale_edit = effect_frame:CreateOrGetControl('edit', kind .. '_scale', 385, y + 60, 55, 25)
    AUTO_CAST(scale_edit)
    scale_edit:SetFontName("white_16_ol")
    scale_edit:SetTextAlign("center", "center")
    scale_edit:SetText("{ol}" .. tostring(Muteki_effect_scale(buff_data, kind)))
    scale_edit:SetTextTooltip(muteki_trans('effect_scale_notice'))
    scale_edit:SetUserValue("KIND", kind)
    scale_edit:SetEventScript(ui.ENTERKEY, "Muteki_effect_scale_edit")
    scale_edit:SetEventScriptArgNumber(ui.ENTERKEY, buff_id)
    -- 透明度を上げるのは通常エフェクトのときだけ意味がある（UI は元から影響を受けない）
    local force_check = effect_frame:CreateOrGetControl('checkbox', kind .. '_force', 15, y + 88, 425, 25)
    AUTO_CAST(force_check)
    force_check:SetText(muteki_trans('effect_force'))
    force_check:SetCheck(Muteki_effect_force(buff_data, kind) and 1 or 0)
    force_check:SetTextTooltip(muteki_trans('effect_force_notice'))
    force_check:SetEventScript(ui.LBUTTONUP, "Muteki_effect_force_toggle")
    force_check:SetEventScriptArgString(ui.LBUTTONUP, kind)
    force_check:SetEventScriptArgNumber(ui.LBUTTONUP, buff_id)
    force_check:ShowWindow(mode == "ui" and 0 or 1)
end

-- 候補の一覧を、今の種類のものだけで詰め直す。
-- 「エフェクトなし」はどちらの種類でも意味が同じなので両方に出す。
function Muteki_effect_fill_presets(effect_frame, kind, buff_id, is_ui)
    local drop_list = GET_CHILD(effect_frame, kind .. "_droplist")
    if not drop_list then
        return
    end
    AUTO_CAST(drop_list)
    drop_list:ClearItems()
    drop_list:AddItem(0, muteki_trans('effect_choose'), 0, "Muteki_effect_noop()")
    local index = 0
    for _, preset in ipairs(g.MUTEKI_EFFECT_PRESETS) do
        local preset_is_ui = preset.ui and true or false
        if preset.name == "None" or preset_is_ui == is_ui then
            index = index + 1
            local preset_text = (g.lang == "Japanese") and preset.ja or preset.etc
            drop_list:AddItem(index, "{ol}" .. preset_text .. " : " .. preset.name, 0,
                string.format("Muteki_effect_select(%d, '%s', '%s')", buff_id, kind, preset.name))
        end
    end
    drop_list:SelectItem(0)
end

-- 種類を選んだとき。名前と大きさは種類ごとに別々に憶えてあるので、ここでは触らない。
function Muteki_effect_type_select(buff_id, kind, mode)
    local buff_data = g.muteki_settings.buff_list[tostring(buff_id)]
    if not buff_data then
        return
    end
    Muteki_effect_mode_set(buff_data, kind, mode)
    g.vlog("muteki: エフェクトの種類を変えた buff=%s kind=%s mode=%s name=%s", tostring(buff_id), tostring(kind),
        tostring(mode), tostring(Muteki_effect_name(buff_data, kind)))
    Muteki_save_settings()
    local effect_frame = ui.GetFrame(addon_name_lower .. "muteki_effect_list")
    if effect_frame then
        Muteki_effect_fill_presets(effect_frame, kind, buff_id, mode == "ui")
        local force_check = GET_CHILD(effect_frame, kind .. "_force")
        if force_check then
            force_check:ShowWindow(mode == "ui" and 0 or 1)
        end
    end
    Muteki_effect_row_refresh(kind, buff_data)
    Muteki_effect_fire(buff_data, kind)
end

-- 「エフェクト中は透明度を自動で上げる」のチェック。
function Muteki_effect_force_toggle(frame, ctrl, kind, buff_id)
    local buff_data = g.muteki_settings.buff_list[tostring(buff_id)]
    if not buff_data then
        return
    end
    local checked = ctrl:IsChecked()
    Muteki_effect_force_set(buff_data, kind, checked)
    g.vlog("muteki: 透明度の自動調整を変えた buff=%s kind=%s check=%s", tostring(buff_id), tostring(kind),
        tostring(checked))
    Muteki_save_settings()
    Muteki_effect_fire(buff_data, kind)
end

-- 大きさの入力欄で Enter を押したとき。数字以外や極端な値は既定へ戻す。
function Muteki_effect_scale_edit(frame, ctrl, str, num)
    local kind = ctrl:GetUserValue("KIND")
    local buff_data = g.muteki_settings.buff_list[tostring(num)]
    if not buff_data then
        return 0
    end
    -- **gsub の戻り値をそのまま tonumber へ渡さないこと。** gsub は (文字列, 置換回数) の
    -- 2 つを返すので、置換回数が tonumber の**基数**として渡って base out of range で落ちる
    -- (1 も 0 も不正。2〜36 しか通らない)。大きさを入れて Enter が無反応だったのはこれ。
    -- another_warehouse の個数変更でも同じ踏み方をしている。一度変数へ受けて 1 つに切る。
    local scale_text = string.gsub(ctrl:GetText() or "", "{ol}", "")
    local scale = tonumber(scale_text)
    -- 戻す先も上限も**種類で変わる**。UI エフェクトは大きさの単位が別で、既定が 12、
    -- 素も 12〜12.5 で使っている。通常エフェクトの既定(6.0 / 1.5)へ戻したり
    -- 30 で頭打ちにしたりすると、UI 側だけ意図しない値になる。
    local is_ui = Muteki_effect_mode(buff_data, kind) == "ui"
    local scale_max = is_ui and 100 or 30
    if not scale or scale <= 0 or scale > scale_max then
        scale = Muteki_effect_default_scale(kind, is_ui)
        ui.SysMsg(muteki_trans('effect_scale_notice'))
    end
    Muteki_effect_scale_set(buff_data, kind, scale)
    g.vlog("muteki: エフェクトの大きさを変えた buff=%s kind=%s scale=%s", tostring(num), tostring(kind),
        tostring(scale))
    Muteki_save_settings()
    ctrl:SetText("{ol}" .. tostring(scale))
    Muteki_effect_fire(buff_data, kind)
    return 0
end

-- 一覧の先頭（「一覧から選ぶ」）を押したときの行き先。何もしない。
function Muteki_effect_noop()
end

function Muteki_effect_list_open(frame, ctrl, ctrl_text, buff_id)
    local buff_id_num = tonumber(buff_id)
    local buff_data = buff_id_num and g.muteki_settings.buff_list[tostring(buff_id_num)]
    if not buff_data then
        return
    end
    local buff_cls = GetClassByType("Buff", buff_id_num)
    local frame_name = addon_name_lower .. "muteki_effect_list"
    local effect_frame = ui.GetFrame(frame_name)
    if not effect_frame then
        effect_frame = ui.CreateNewFrame("notice_on_pc", frame_name, 0, 0, 10, 10)
        AUTO_CAST(effect_frame)
        g.block_click_through(effect_frame)
        effect_frame:SetSkinName("test_frame_low")
        effect_frame:SetPos(610, 30)
        effect_frame:SetLayerLevel(999)
    end
    AUTO_CAST(effect_frame)
    -- 別のバフを開いたときに前のバフの段が残らないよう、中身は毎回作り直す。
    -- **フレームごと DestroyFrame してはいけない。** 同じ tick で作り直すと窓が出ないまま
    -- 消えた状態になり、「開いている最中に別のバフのエフェクトボタンを押すと窓が閉じる」
    -- という出方をする(実機で確認)。入れ物は使い回して子だけ捨てる。
    effect_frame:RemoveAllChild()
    local title_text = effect_frame:CreateOrGetControl('richtext', 'title_text', 15, 15, 10, 30)
    AUTO_CAST(title_text)
    local buff_name = buff_cls and dictionary.ReplaceDicIDInCompStr(buff_cls.Name) or tostring(buff_id_num)
    title_text:SetText("{#000000}{s20}" .. muteki_trans('effect_title') .. " : " .. buff_name)
    local close_button = effect_frame:CreateOrGetControl('button', 'close_button', 0, 0, 20, 20)
    AUTO_CAST(close_button)
    close_button:SetImage("testclose_button")
    close_button:SetGravity(ui.RIGHT, ui.TOP)
    close_button:SetEventScript(ui.LBUTTONUP, "Muteki_effect_list_close")
    Muteki_effect_row(effect_frame, "start", 55, buff_id_num, buff_data)
    -- 重複が最大になったときのエフェクトは、重複するバフにしか出番が無い
    if buff_cls and buff_cls.OverBuff and buff_cls.OverBuff > 1 then
        Muteki_effect_row(effect_frame, "over", 180, buff_id_num, buff_data)
        effect_frame:Resize(470, 310)
    else
        effect_frame:Resize(470, 185)
    end
    effect_frame:ShowWindow(1)
    g.esc_register_destroy(frame_name)
end

function Muteki_effect_list_close(frame, ctrl, str, num)
    ui.DestroyFrame(frame:GetName())
end

-- 一覧から選んだとき。設定を書いて入力欄へ写し、その場で再生して見た目を確かめられるようにする。
function Muteki_effect_select(buff_id, kind, effect_name)
    local buff_id_str = tostring(buff_id)
    local buff_data = g.muteki_settings.buff_list[buff_id_str]
    if not buff_data then
        return
    end
    Muteki_effect_name_set(buff_data, kind, effect_name)
    -- 候補から選んだときは、大きさもそのエフェクトの目安に合わせる
    -- （エフェクトごとに素の大きさが違い、6.0 のままだと大きすぎる / 小さすぎるため）
    local preset = Muteki_effect_preset(effect_name)
    if preset and preset.scale then
        Muteki_effect_scale_set(buff_data, kind, preset.scale)
    end
    g.vlog("muteki: エフェクトを変えた buff=%s kind=%s name=%s mode=%s", buff_id_str, tostring(kind),
        tostring(effect_name), tostring(Muteki_effect_mode(buff_data, kind)))
    Muteki_save_settings()
    ui.SysMsg(string.format(muteki_trans('effect_set'), effect_name))
    Muteki_effect_row_refresh(kind, buff_data)
    Muteki_effect_fire(buff_data, kind)
end

-- 設定窓が開いていれば、その段の表示を今の設定に合わせ直す。
function Muteki_effect_row_refresh(kind, buff_data)
    local effect_frame = ui.GetFrame(addon_name_lower .. "muteki_effect_list")
    if not effect_frame then
        return
    end
    local name_edit = GET_CHILD(effect_frame, kind .. "_edit")
    if name_edit then
        name_edit:SetText("{ol}" .. Muteki_effect_name(buff_data, kind))
    end
    local scale_edit = GET_CHILD(effect_frame, kind .. "_scale")
    if scale_edit then
        scale_edit:SetText("{ol}" .. tostring(Muteki_effect_scale(buff_data, kind)))
    end
    local force_check = GET_CHILD(effect_frame, kind .. "_force")
    if force_check then
        AUTO_CAST(force_check)
        force_check:SetCheck(Muteki_effect_force(buff_data, kind) and 1 or 0)
    end
    local use_check = GET_CHILD(effect_frame, kind .. "_use")
    if use_check then
        AUTO_CAST(use_check)
        use_check:SetCheck(Muteki_effect_enabled(buff_data, kind) and 1 or 0)
    end
end

-- ON/OFF のチェック。開始時のぶんは設定画面の「エフェクト付与」と同じ値を書くので、
-- 設定画面が開いていれば、そちらのチェックも合わせ直す。
function Muteki_effect_use_toggle(frame, ctrl, kind, buff_id)
    local buff_data = g.muteki_settings.buff_list[tostring(buff_id)]
    if not buff_data then
        return
    end
    local checked = ctrl:IsChecked()
    Muteki_effect_enabled_set(buff_data, kind, checked)
    g.vlog("muteki: エフェクトの ON/OFF を変えた buff=%s kind=%s check=%s", tostring(buff_id), tostring(kind),
        tostring(checked))
    Muteki_save_settings()
    if kind ~= "over" and ui.GetFrame(addon_name_lower .. "muteki_settings") then
        Muteki_setting_frame_init()
    end
    if checked == 1 then
        Muteki_effect_fire(buff_data, kind)
    end
end

-- 入力欄で Enter を押したとき。一覧の選択は戻して、入力欄の中身だけが正本になるようにする。
function Muteki_effect_edit(frame, ctrl, str, num)
    local kind = ctrl:GetUserValue("KIND")
    local effect_name = ctrl:GetText() or ""
    effect_name = string.gsub(effect_name, "{ol}", "")
    effect_name = string.gsub(effect_name, "%s", "")
    if effect_name == "" then
        effect_name = "None"
    end
    Muteki_effect_select(num, kind, effect_name)
    local effect_frame = ui.GetFrame(addon_name_lower .. "muteki_effect_list")
    if effect_frame then
        local drop_list = GET_CHILD(effect_frame, kind .. "_droplist")
        if drop_list then
            AUTO_CAST(drop_list)
            drop_list:SelectItem(0)
        end
    end
    return 0
end

function Muteki_effect_test(frame, ctrl, kind, buff_id)
    local buff_data = g.muteki_settings.buff_list[tostring(buff_id)]
    Muteki_effect_fire(buff_data, kind)
end

function Muteki_setting_frame_close(parent, ctrl)
    local settings = parent:GetTopParentFrame()
    ui.DestroyFrame(settings:GetName())
    local buff_list_frame_name = addon_name_lower .. "muteki_buff_list"
    local buff_list_frame = ui.GetFrame(buff_list_frame_name)
    if buff_list_frame then
        Muteki_buff_list_close(buff_list_frame, "", "", "")
    end
    local skill_list_frame_name = addon_name_lower .. "muteki_skill_list"
    local skill_list_frame = ui.GetFrame(skill_list_frame_name)
    if skill_list_frame then
        Muteki_skill_list_close(skill_list_frame, "", "", "")
    end
    local effect_list_frame = ui.GetFrame(addon_name_lower .. "muteki_effect_list")
    if effect_list_frame then
        Muteki_effect_list_close(effect_list_frame, "", "", "")
    end
end
-- muteki ここまで

