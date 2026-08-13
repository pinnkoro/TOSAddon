function Mini_addons_CHAT_SYSTEM(msg, color)
    if msg and g.settings.chat_system == 1 then
        if msg == "&lt완벽함&gt 효과가 사라졌습니다." or msg ==
            "&lt완벽함&gt 효과가 발동되었습니다." or msg == "@dicID_^*$ETC_20220830_069434$*^" or msg ==
            "@dicID_^*$ETC_20220830_069435$*^" or msg == "[__m2util] is loaded" or msg == "[adjustlayer] is loaded" or
            msg == "[extendcharinfo] is loaded" or msg == "[ICC]Attempt to CC." or
            -- string.find は既定でパターン照合なので、必ず plain(第 4 引数 true)で呼ぶこと。
            -- "[__m2util] is loaded" をそのまま渡すと "[...]" が文字クラスと解釈され、
            -- 「_ m 2 u t i l のどれか 1 文字 + ' is loaded'」に化けて、無関係な
            -- システムメッセージ("t is loaded" 等)まで握り潰していた。
            string.find(msg, "StartBlackMarketBetween", 1, true) or
            string.find(msg, "[__m2util] is loaded", 1, true) or
            string.find(msg, "[adjustlayer] is loaded", 1, true) or string.find(msg, "MapMate", 1, true) then
            return
        end
    end
    -- 色は呼び出し元の指定をそのまま渡す。個別版はここで "FFFF00" 固定にしていたが、
    -- まとめ版では同じ CHAT_SYSTEM に他アドオンも乗るため、赤いエラー文も本家検出の
    -- {#FF6347} の告知も、他アドオンの色付きメッセージも全部黄色になってしまう。
    g.FUNCS["CHAT_SYSTEM"](msg, color)
end
