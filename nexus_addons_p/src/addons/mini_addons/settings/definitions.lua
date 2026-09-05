-- !追加の度に更新
local DEFAULT_SETTINGS = {
    reword_x = 1100,
    reword_y = 100,
    allcall = 0,
    under_staff = 0,
    raid_record = 0,
    party_buff = 0,
    chat_system = 0,
    channel_display = 0,
    channel_info = 0,
    mini_btn = 0,
    market_display = 0,
    restart_move = 0,
    pet_init = 0,
    dialog_ctrl = 0,
    auto_cast = 0,
    auto_casting = {},
    coin_use = 0,
    equip_info = 0,
    automatch_layer = 0,
    quest_hide = 0,
    pc_name = 0,
    auto_gacha = 0,
    auto_gacha_start = 0,
    skill_enchant = 0,
    party_info = 0,
    relic_gauge = 0,
    raid_check = 0,
    coin_count = 0,
    bgm = 0,
    my_effect = 0,
    other_effect = 0,
    boss_effect = 0,
    vakarine = 0,
    weekly_boss_reward = 0,
    solodun_reward = 0,
    cupole_portion = {
        use = 0,
        x = 0,
        y = 0,
        def_x = 0,
        def_y = 0
    },
    goodbye_ragana = 0,
    -- 決闘の申し込みを自動で受ける。既定は 0(OFF)。**既定を 1 にしないこと。**
    -- 断る自由を黙って奪うことになるので、明示的に ON にした人だけに効かせる。
    auto_accept_duel = 0,
    status_upgrade = 0,
    icor_status_search = 0,
    velnice = {
        use = 0,
        level = ""
    },
    separated_buff = 0,
    group_name = {},
    group_chat = 0,
    memberinfo = 0,
    baubas_call = {
        use = 0,
        guild_notice = 0
    },
    chat_recv = 0,
    pet_ring = 0,
    daily_quest = 0,
    chat_frame = 0,
    restart_colony = 0,
    auto_zoom = {
        use = 0,
        zoom = 336
    },
    rp_charge = 0,
    skill_cool_sound = 0,
    inventory_mod = 0,
    reroll_option = 0,
    -- スキルと特性のウィンドウで、特性をスキル順に並べる
    ability_sort = 0,
    hair_enchant = 0,
    -- ヘアエンチャントの「高度な設定」窓を、素材を乗せた時点で自動で開くか
    hair_enchant_auto_open = 0,
    -- 高度な設定のプリセット。**配列**(1 始まり)で枠数は決めない。1 件の中身は
    --   {name = 表示名, options = {オプションのクラス名, ...}, rank = "B"/"None",
    --    repeat_count = 数, fast = 0/1}
    -- **オプションはクラス名で持つこと。** 画面のチェックの名前(option_text<番号>)は
    -- enchant_special_option の並び順に依存し、出る項目もランクで変わるため、
    -- 番号で保存すると別のオプションを復元しかねない
    hair_enchant_presets = {},
    skill_reroll = 0,
    -- スキル錬成の「高度な設定」窓を、アイテムを乗せた時点で自動で開くか
    skill_reroll_auto_open = 0,
    -- 高度な設定のプリセット。**配列**(1 始まり)で枠数は決めない。1 件の中身は
    --   {name = 表示名, skills = {{class = スキルのクラス名, min_lv = 数}, ...}, repeat_count = 数}
    -- **スキルはクラス名で持つこと。** 画面の並びは表示名順なので、番号で保存すると
    -- 辞書や言語が変わっただけで別のスキルを復元しかねない
    skill_reroll_presets = {},
    new_groups = {},
    chat_new_btn = 0,
    chat_xy = {},
    pt_info = 0,
    enchant_tooltip = 0,
    boss_rank = 0,
    auto_craft = 0,
    keep_first = 0,
    multiple_item = 0,
    event_shout = {
        use = 0,
        guild_notice = 0
    },
    select_bgm = "",
    -- アイテム破片化の窓を拡張する。col / row はスロットの列数・行数(既定は素と同じ 5x5)
    fragmentation = {
        use = 0,
        col = 5,
        row = 5,
        -- 「破片化しないで残す条件」。1 件 = {ctrl=系統, cls=クラス, rank=1〜3, lv=1〜5}。
        -- 指定しない項目はキーごと持たない(= 指定なし)
        keep = {}
    },
    -- 設定画面のセクションを畳んでいるか（キーは SETTING_SECTIONS の name、1 で折りたたみ）
    section_collapsed = {}
}

local SETTINGS_NAME = {"other_effect", "my_effect", "boss_effect", "channel_info", "pc_name", "quest_hide",
                       "automatch_layer", "equip_info", "under_staff", "raid_record", "party_buff", "chat_system",
                       "channel_display", "mini_btn", "market_display", "restart_move", "pet_init", "dialog_ctrl",
                       "auto_cast", "coin_use", "auto_gacha", "skill_enchant", "party_info", "relic_gauge",
                       "raid_check", "coin_count", "bgm", "vakarine", "weekly_boss_reward", "solodun_reward",
                       "cupole_portion", "goodbye_ragana", "status_upgrade", "icor_status_search", "velnice",
                       "separated_buff", "group_chat", "memberinfo", "baubas_call", "pt_buff", "chat_recv", "pet_ring",
                       "daily_quest", "chat_frame", "restart_colony", "auto_zoom", "rp_charge", "skill_cool_sound",
                       "inventory_mod", "reroll_option", "hair_enchant", "skill_reroll", "chat_new_btn", "pt_info",
                       "enchant_tooltip", "boss_rank", "auto_craft", "keep_first", "multiple_item", "event_shout",
                       "auto_accept_duel", "ability_sort", "fragmentation"}

local COIN_ITEM = {869001, 11200350, 11200303, 11200302, 11200301, 11200300, 11200299, 11200298, 11200297, 11200161,
                   11200160, 11200159, 11200158, 11200157, 11200156, 11200155, 11030215, 11030214, 11030213, 11030212,
                   11030211, 11030210, 11030201, 11035673, 11035670, 11035668, 11030394, 11030240, 646076, 11035672,
                   11035669, 11035667, 11035457, 11035426, 11035409, 11201239, 11201238, 11201237, 11201236, 11201235,
                   11201234, 11201233, 11201232, 11202008, 11202007, 11202006, 11202005, 11202004, 11202003, 11202002,
                   11202001,
                   -- サウレ(Lv560 の女神)のコイン。1p / 100p / 1000p / 5000p / 10000p / 50000p / 1000000p と
                   -- dummy_SauleCertificate。他の女神と同じく 8 個ひと組で並べる
                   11202092, 11202091, 11202090, 11202089, 11202088, 11202087, 11202086, 11202085}

-- 設定項目の文言定義（その 1）。上流では設定画面の先頭に並べていた分。
-- どのセクションに出すかは SETTING_SECTIONS 側で決めるので、ここの並びは表示順ではない
local MAIN_FRAME_SETTINGS = {{
    name = "event_shout",
    text_jp = "イベントグローバルシャウトをチャットに表示",
    text_kr = "이벤트 글로벌 샤우트를 채팅에 표시",
    text_en = "Displays Event Global Shouts in the chat",
    updated = "2.1.0",
    updated_note_jp = "フィールドボスの出現・討伐のお知らせが、日本語 / 英語でも出るようになりました",
    updated_note_en = "Field boss spawn/defeat notices now appear in Japanese / English too"
}, {
    name = "multiple_item",
    text_jp = "メレジナハード以降のハードレイドで追加報酬券お知らせ",
    text_kr = "메레지나 하드 이후의 하드 레이드에서 추가 보상권 알림",
    text_en = "Merregina Hard & above Hard Raids: Bonus Ticket Notice"
}, {
    name = "keep_first",
    text_jp = "週ボスダメージ報酬の1段目を残すボタンを作成",
    text_kr = "주간 보스 보상 첫 번째 유지 컨트롤 생성",
    text_en = "Create Weekly Boss Damage Reward 1st Keep Control"
}, {
    name = "auto_craft",
    text_jp = "アイテム製造時 自動でセットします",
    text_kr = "아이템 제조 시 자동으로 세트됩니다",
    text_en = "Automatically set during item crafting"
}, {
    name = "boss_rank",
    text_jp = "ボスレイドのビルドランキング作成",
    text_kr = "보스 레이드 빌드 랭킹 생성",
    text_en = "Create the build ranking for boss raids"
}, {
    name = "enchant_tooltip",
    text_jp = "スキル錬成スロットにツールチップ追加",
    text_kr = "스킬 인챈트 슬롯에 툴팁을 추가했습니다",
    text_en = "Added tooltips to the skill enchantment slots"
}, {
    name = "pt_info",
    text_jp = "PT情報にメンバーの場所追加",
    text_kr = "PT 정보에 멤버 위치를 추가했습니다",
    text_en = "Added member locations to PT information"
}, {
    name = "chat_new_btn",
    text_jp = "チャット入力フレームにボタン追加",
    text_kr = "채팅 입력 창에 버튼을 추가했습니다",
    text_en = "Added a button to the chat input frame"
}, {
    name = "hair_enchant",
    text_jp = "ヘアアクセサリーのエンチャント自動付与を使いやすく",
    text_kr = "헤어 액세서리 자동 인챈트 사용성 개선",
    text_en = "Hair Accessory Auto-Enchant UX improved",
    -- 「更新」の印。**採番するまでは core_g.VER_NEXT を書く**(CLAUDE.md の先行採番の禁止)。
    -- 古くなった updated は 2〜3 版で消すこと(残すと印だらけになって意味を失う)。
    updated = "2.4.0",
    updated_note_jp = "「ランクアップ時に停止」が効かないことがあったのと、回している最中に別のヘアアクセへ載せ替えると 1 回で止まることがあったのを修正しました",
    updated_note_en = "Fixed \"stop on rank up\" sometimes not working, and stopping after one roll when you swap to another hair accessory mid-run"
}, {
    name = "skill_reroll",
    text_jp = "スキル錬成を希望スキルが出るまで回せるように",
    text_kr = "스킬 연성을 원하는 스킬이 나올 때까지 반복",
    text_en = "Keep re-rolling Skill Enchant until a wanted skill shows up",
    -- 「NEW」の印。**since は一度書いたら触らないこと**(触ると追加と改修の区別が付かない)。
    since = "2.2.0"
}, {
    name = "reroll_option",
    text_jp = "オプション設定の数値表を常に表示",
    text_kr = "옵션 설정의 수치 표를 항상 표시합니다",
    text_en = "Always display the numerical table for option settings"
}, {
    name = "ability_sort",
    text_jp = "特性をスキル順に並べる",
    text_kr = "특성을 스킬 순서로 정렬",
    text_en = "Sort abilities in skill order",
    -- 「NEW」の印。**採番するまでは core_g.VER_NEXT を書く**(CLAUDE.md の先行採番の禁止)。
    since = "2.4.0",
    updated = core_g.VER_NEXT,
    updated_note_jp = "特性の窓を閉じているときにも並べ替えが走っていたのをやめました。装備を替えたときの引っかかりが減ります",
    updated_note_en = "Stopped sorting while the ability window is closed. Changing equipment stutters less"
}, {
    name = "fragmentation",
    text_jp = "アイテム破片化の枠を拡張し、耳飾りを細かく絞り込む",
    text_kr = "아이템 파편화 슬롯을 확장하고 귀걸이를 세분화해 필터링",
    text_en = "Expand the Item Fragmentation grid and filter earrings in more detail",
    -- 「NEW」の印。**採番するまでは core_g.VER_NEXT を書く**(CLAUDE.md の先行採番の禁止)。
    since = core_g.VER_NEXT
}, {
    name = "inventory_mod",
    text_jp = "インベントリのスロットを少し改造",
    text_kr = "인벤토리 슬롯을 약간 개조했습니다",
    text_en = "Slightly modified the inventory slots",
    updated = "2.3.1",
    updated_note_jp = "Lv560 のイコルと肩・ベルトが「格下」の枠で出ていたのと、Lv560 のエーテルジェムに枠が付かなかったのを直しました",
    updated_note_en = "Fixed Lv560 ichors and shoulder/belt gear being drawn with the lower-tier frame"
}, {
    name = "auto_zoom",
    text_jp = "マップ切り替え時に自動でズーム",
    text_kr = "맵 이동 시 자동으로 지도를 확대합니다",
    text_en = "Automatically zooms the map when changing maps"
}, {
    name = "restart_colony",
    text_jp = "コロニー死亡時の30秒タイマーを修正",
    text_kr = "콜로니 사망 시 30초 타이머 수정",
    text_en = "Fixed the 30-second timer on death in Colonies"
}, {
    name = "under_staff",
    text_jp = "4人以下の入場確認をスキップ",
    text_kr = "4인 이하 입장 확인 건너뛰기",
    text_en = "Skip confirmation for admission of 4 or fewer people"
}, {
    name = "party_buff",
    text_jp = "PTメンバーのバフを非表示",
    text_kr = "파티원 버프 숨기기",
    text_en = "Hide buffs for party members"
}, {
    name = "channel_display",
    text_jp = "チャンネル表示のズレを修正(日本語版)",
    text_kr = "채널 표시 오류 수정(일본어)",
    text_en = "Fixed channel display misalignment for Japanese ver"
}, {
    name = "coin_count",
    text_jp = "各商店のコイン上限を99999に",
    text_kr = "각 상점 코인 상한을 99999로",
    text_en = "Raise coin limit to 99999 for each shop"
}, {
    name = "bgm",
    text_jp = "街でBGMプレイヤーを常にオンにする",
    text_kr = "도시에서는 항상 BGM 플레이어를 재생합니다",
    text_en = "Always play BGM in the city"
}, {
    name = "icor_status_search",
    text_jp = "インベントリでイコルのステータスを検索 半角スペースでor検索",
    text_kr = "인벤토리에서 아이커 능력치 검색 반각 공백으로 OR 검색",
    text_en = "Search Icor status in Inventory OR search using half-width spaces"
}, {
    name = "velnice",
    text_jp = "ヴェルニケの以前の階層を覚える",
    text_kr = "벨니케의 이전 레벨을 기억하다",
    text_en = "Remember Velnice's previous level"
}, {
    name = "memberinfo",
    text_jp = "各種右クリックメニューにメンバーインフォを追加",
    text_kr = "각종 오른쪽 클릭 메뉴에 멤버 정보 추가",
    text_en = "Add member info to various right-click menus"
}}
-- 設定項目の文言定義（その 2）。上流ではカテゴリ別のサブウィンドウに出していた分。
-- こちらもキーは由来を示すだけで、表示先は SETTING_SECTIONS が決める
local SUB_FRAME_SETTINGS = {
    chats = {{
        name = "chat_system",
        text_jp = "パーフェクトとブラックマーケットのお知らせをチャットに表示しません",
        text_kr = "완벽함 메시지 및 블랙 마켓 공지를 채팅에 표시 하지 않습니다",
        text_en = "Perfect and Black Market notices not displayed in chat"
    }, {
        name = "group_chat",
        text_jp = "グループチャットをチャットフレームから選択出来ます",
        text_kr = "채팅 프레임에서 그룹 채팅을 선택할 수 있습니다",
        text_en = "Group chats can be selected from chat frame"
    }, {
        name = "baubas_call",
        text_jp = "バウバス登場をお知らせ",
        text_kr = "바우버스 등장 소식",
        text_en = "Announcing the arrival of Baubas",
        updated = "2.1.0",
        updated_note_jp = "お知らせが日本語 / 英語でも出るようになり、討伐の取りこぼしを減らしました",
        updated_note_en = "Notices now appear in Japanese / English; fewer missed defeat notices"
    }, {
        name = "chat_recv",
        text_jp = "PTメンバーの死亡をニコチャットで表示",
        text_kr = "PT 멤버의 사망을 니코챗으로 표시하기",
        text_en = "Death of a PT member is indicated in Nicochat"
    }, {
        name = "chat_frame",
        text_jp = "ワイドモニターの追加チャットフレームの移動制限解除",
        text_kr = "와이드 모니터에서 추가 채팅창의 이동 제한 해제",
        text_en = "Freely move additional chat frames on wide monitors"
    }},
    chars = {{
        name = "my_effect",
        text_jp = "自分のエフェクトを調整します(1~100)",
        text_kr = "나만의 효과를 조정합니다(1~100)",
        text_en = "Adjust my effects(1~100)"
    }, {
        name = "other_effect",
        text_jp = "他人のエフェクトを調整します(1~100)",
        text_kr = "다른 사람의 효과를 조정합니다(1~100)",
        text_en = "Adjust other people's effects(1~100)"
    }, {
        name = "boss_effect",
        text_jp = "ボスのエフェクトを調整します(1~100)",
        text_kr = "보스 효과를 조정합니다(1~100)",
        text_en = "Adjust boss effects(1~100)"
    }, {
        name = "auto_cast",
        text_jp = "オートキャスティングをキャラ毎に設定",
        text_kr = "캐릭터별로 자동 시전 설정",
        text_en = "Set auto casting per character"
    }, {
        name = "pc_name",
        text_jp = "左上の名前をキャラクター名に変更します",
        text_kr = "좌측 상단의 이름을 캐릭터 이름으로 변경합니다",
        text_en = "Change the name in the top left to your character's name"
    }, {
        name = "relic_gauge",
        text_jp = "キャラクターゲージにレリックを追加します",
        text_kr = "캐릭터 게이지에 유물을 추가합니다",
        text_en = "Add a Relic to the character's gauge"
    }, {
        name = "equip_info",
        text_jp = "アーク/エンブレム装備忘れ通知",
        text_kr = "아크/엠블렘 장비 미착용 알림",
        text_en = "Notification for unequipped Ark/Emblem"
    }, {
        name = "vakarine",
        text_jp = "レイドでヴァカリネ装備を通知",
        text_kr = "레이드에서 바카리네 장비 알림",
        text_en = "Vakarine Equipment Notification in Raids"
    }, {
        name = "skill_cool_sound",
        text_jp = "スキル連打時のクールタイムの音を消去",
        text_kr = "스킬 연타 시의 재사용 대기시간(쿨타임) 효과음을 삭제했습니다",
        text_en = "Removed the cooldown sound when a skill is spammed"
    }},
    frames = {{
        name = "raid_record",
        text_jp = "レイドレコードを移動可能にしてサイズを変更",
        text_kr = "레이드 기록의 이동이 가능하고, 크기 조절을 할 수 있습니다",
        text_en = "Raid records movable and resizable"
    }, {
        name = "mini_btn",
        text_jp = "レイド時右上のミニボタン非表示",
        text_kr = "레이드 중 오른쪽 상단의 미니 버튼을 숨깁니다",
        text_en = "Hide minibutton in upper right corner during raid"
    }, {
        name = "market_display",
        text_jp = "街では、右上の商店一覧を常に表示します",
        text_kr = "도시 이동 시 상점 목록을 항상 열어둡니다",
        text_en = "Keep shop list open when moving to city"
    }, {
        name = "restart_move",
        text_jp = "リスタート時の選択肢フレームを動かせる様にします",
        text_kr = "재시작 시 선택 프레임을 이동할 수 있게 합니다",
        text_en = "Allow moving selection frame on restart"
    }, {
        name = "automatch_layer",
        text_jp = "オートマッチ時のフレームのレイヤーレベルを下げます",
        text_kr = "자동 매칭 시 프레임 레이어 레벨을 낮춥니다",
        text_en = "Lower frame layer level during auto match"
    }, {
        name = "quest_hide",
        text_jp = "クエストリストを非表示にします",
        text_kr = "퀘스트 목록을 숨깁니다",
        text_en = "Hide the quest list"
    }, {
        name = "channel_info",
        text_jp = "チャンネル切替フレームを表示します",
        text_kr = "채널 전환 프레임을 표시합니다",
        text_en = "Displays the channel switching frame"
    }, {
        name = "auto_gacha",
        text_jp = "女神の加護ガチャフレーム表示を自動化します",
        text_kr = "여신의 가호 가챠 프레임 표시를 자동화합니다",
        text_en = "Automate the display of the Goddess Protection gacha frame"
    }, {
        name = "party_info",
        text_jp = "パーティー情報フレームをバフ数に合わせてリサイズ",
        text_kr = "파티 정보 프레임을 버프 수에 맞춰 리사이즈",
        text_en = "Resized the party information frame to match the number of buffs"
    }, {
        name = "cupole_portion",
        text_jp = "クポルのポーションフレームを非表示に。OFFでもフレームの位置記憶",
        text_kr = "큐폴의 포션 프레임을 숨기고, OFF 상태에서도 프레임 위치를 기억합니다",
        text_en = "Hide the potion frame of the cupole.Memorizes frame position even when OFF"
    }, {
        name = "separated_buff",
        text_jp = "セパレートバフフレームの周りを綺麗にします",
        text_kr = "분리형 버프 프레임 주변을 없앱니다",
        text_en = "Eliminate around separate buff frame"
    }, {
        name = "pet_ring",
        text_jp = "ペットリングフレームを非表示にします",
        text_kr = "펫 링 프레임을 숨깁니다",
        text_en = "Hides the pet ring frame"
    }, {
        name = "daily_quest",
        text_jp = "デイリークエストを別窓で表示",
        text_kr = "일일 퀘스트를 별도 창에 표시합니다",
        text_en = "Display the daily quest in a separate window"
    }},
    autos = {{
        name = "coin_use",
        text_jp = "各種コインを取得時に自動で使用します",
        text_kr = "각종 코인 획득 시 자동 사용",
        text_en = "Automatically use various coins upon acquisition",
        updated = "2.3.0",
        updated_note_jp = "サウレ（Lv560 の女神）のコインも自動で使うようになりました",
        updated_note_en = "Now also auto-uses Saule (the Lv560 goddess) coins"
    }, {
        name = "skill_enchant",
        text_jp = "スキル錬成のアイテムを自動でセットします",
        text_kr = "스킬 연성을 위한 아이템을 자동으로 설정합니다",
        text_en = "Automatically sets items for skill refining"
    }, {
        name = "weekly_boss_reward",
        text_jp = "週間ボスレイド報酬を自動で受け取り",
        text_kr = "주간 보스 레이드 보상을 자동으로 수령",
        text_en = "Receive weekly boss reward automatically"
    }, {
        name = "solodun_reward",
        text_jp = "ヴェルニケダンジョン報酬を自動で受け取り",
        text_kr = "벨니체 던전 보상 자동 받기",
        text_en = "Receive Velnice dungeon reward automatically"
    }, {
        name = "status_upgrade",
        text_jp = "装備錬成、武器防具ステータス付与を自動化",
        text_kr = "장비 연성, 무기 방어구 스테이터스 부여 자동화",
        text_en = "Equip Refining, Automate weapon/armor enhancement"
    }, {
        name = "dialog_ctrl",
        text_jp = "各種ダイアログを制御",
        text_kr = "각종 다이얼로그 제어",
        text_en = "Controls various dialogs"
    }, {
        name = "auto_accept_duel",
        text_jp = "決闘の申し込みを自動で受ける",
        text_kr = "결투 신청을 자동으로 수락",
        text_en = "Automatically accept duel requests"
    }, {
        name = "goodbye_ragana",
        text_jp = "街でラガナを非表示",
        text_kr = "마을에서 라가나 숨기기",
        text_en = "Hide Ragana in city"
    }, {
        name = "rp_charge",
        text_jp = "レリック自動補充を補完",
        text_kr = "레릭 자동 보충 기능에 보완(복구) 기능이 추가되었습니다",
        text_en = "Relic auto-replenishment now includes a recovery function"
    }}
}

-- 設定画面のセクション定義。以前はカテゴリのボタンを押して別ウィンドウ(sub_frame)を
-- 開いていたが、検索でまとめて絞り込めるよう 1 枚のスクロールする一覧に統合し、
-- ここの見出しで区切って並べる。順序はそのまま表示順になる。
--
-- 中身は文言の定義そのものではなく **設定名の並び** で持つ。上の
-- MAIN_FRAME_SETTINGS / SUB_FRAME_SETTINGS は上流由来でどちらに書かれているかが
-- 分類と一致していないので、「どこに出すか」はここだけ見れば分かる形に分けてある
-- （項目を別のセクションへ移すときに、文言のブロックを動かさなくて済む）。
local SETTING_SECTIONS = {{
    name = "chats",
    names = {"chat_system", "group_chat", "baubas_call", "chat_recv", "chat_frame", "event_shout", "multiple_item",
             "chat_new_btn"},
    text_jp = "チャット関連",
    text_kr = "채팅 관련",
    text_en = "Chat-related"
}, {
    name = "chars",
    names = {"my_effect", "other_effect", "boss_effect", "auto_cast", "pc_name", "relic_gauge", "equip_info",
             "vakarine", "skill_cool_sound"},
    text_jp = "キャラクター関連",
    text_kr = "캐릭터 관련",
    text_en = "Character-related"
}, {
    name = "frames",
    names = {"raid_record", "mini_btn", "market_display", "restart_move", "restart_colony", "automatch_layer",
             "quest_hide", "channel_info", "channel_display", "auto_gacha", "party_info", "pt_info", "party_buff",
             "cupole_portion", "separated_buff", "pet_ring", "daily_quest", "inventory_mod", "icor_status_search",
             "reroll_option", "enchant_tooltip", "keep_first", "boss_rank", "memberinfo", "ability_sort",
             "fragmentation"},
    text_jp = "フレーム関連",
    text_kr = "프레임 관련",
    text_en = "Frame-related"
}, {
    name = "autos",
    names = {"coin_use", "skill_enchant", "weekly_boss_reward", "solodun_reward", "status_upgrade", "dialog_ctrl",
             "under_staff", "auto_accept_duel", "goodbye_ragana", "rp_charge", "auto_craft", "hair_enchant",
             "skill_reroll", "auto_zoom", "velnice"},
    text_jp = "自動処理関連",
    text_kr = "자동 처리 관련",
    text_en = "Automation-related"
}, {
    -- どのセクションにも当てはまらないものの受け皿。必ず最後に置くこと
    -- （下の振り分けで、名前を書き忘れた項目もここへ落とすため）
    name = "etc",
    names = {"coin_count", "bgm"},
    text_jp = "その他",
    text_kr = "기타",
    text_en = "Other"
}}

-- 上の names を実際の定義（文言）に解決して section.items に詰める。
-- 名前を書き忘れた項目は最後のセクション(その他)へ回す。定義に足しただけで
-- 画面から黙って消えるのを防ぐため。
do
    local defs = {}
    local order = {}
    local sources = {MAIN_FRAME_SETTINGS, SUB_FRAME_SETTINGS.chats, SUB_FRAME_SETTINGS.chars, SUB_FRAME_SETTINGS.frames,
                     SUB_FRAME_SETTINGS.autos}
    for _, list in ipairs(sources) do
        for _, def in ipairs(list) do
            if not defs[def.name] then
                defs[def.name] = def
                order[#order + 1] = def.name
            end
        end
    end
    local placed = {}
    for _, section in ipairs(SETTING_SECTIONS) do
        section.items = {}
        for _, name in ipairs(section.names) do
            if defs[name] and not placed[name] then
                placed[name] = true
                section.items[#section.items + 1] = defs[name]
            end
        end
    end
    local last = SETTING_SECTIONS[#SETTING_SECTIONS].items
    for _, name in ipairs(order) do
        if not placed[name] then
            last[#last + 1] = defs[name]
        end
    end
    -- まとめ版の一覧(core/20_lifecycle.lua)の Mini Addons の行へ、設定項目の新着を
    -- 集約して出せるようにする。**ここで預けないと気付けない**: 設定を 1 つ足しても
    -- 一覧の行の見た目は変わらないので、一覧しか見ていない人には増えたことが伝わらない。
    -- 集約と印の決め方は core_g.badge_row。
    local all = {}
    for _, name in ipairs(order) do
        all[#all + 1] = defs[name]
    end
    -- **入れ物が無い前提で書くこと。** ここはチャンクの読み込み中に走るので、
    -- core_g.badge_children が nil のまま添字を引くと**その場で読み込みが止まり、
    -- これより後ろの定義がまるごと失われる**（後続の market_favorite_rebuild などが
    -- 丸ごと消える）。core が古い / 差し替えられた場合にも耐えるようにする。
    core_g.badge_children = core_g.badge_children or {}
    core_g.badge_children["mini_addons"] = all
end

