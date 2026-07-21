<!--
  feature ブランチ -> main 用の PR テンプレート。
  URL の末尾に ?template=feature.md を付けると、このテンプレートで本文が埋まります。
  例) https://github.com/pinnkoro/TOSAddon/compare/main...<ブランチ>?template=feature.md
-->

## 概要

<!-- 何を・なぜ変更したか（1〜3行） -->

## 対象アドオン / バージョン

- アドオン名:
- バージョン: `vX.Y.Z`（ソースの `ver` と `addons.json` の `fileVersion` に一致させる）

## 変更内容

-

## 動作確認

<!-- ゲーム内での確認結果・確認できていない点など -->

## チェックリスト

- [ ] 編集は `nexus_addons_p/src/**` 側で行った（生成物の bundle `.lua` は直接編集していない）
- [ ] `python docs/bundle_from_src.py --bless` → `python docs/bundle_from_src.py` で bundle を再生成した
- [ ] `.ipf` を再ビルドし、`python docs/verify_ipf.py` で src との一致を確認した（`docs/BUILD_IPF.md` §4）
- [ ] `addons.json` の `fileVersion` を更新した
- [ ] **`nexus_addons_p/README.md` の更新履歴に追記した**（既存エントリの先頭 / CLAUDE.md ルール）
- [ ] 新バージョンなら旧 `.ipf` を `nexus_addons_p/_old/` へ移動した

<!--
  配布（GitHub Release への公開）は main へマージした後、別途 main -> release の PR
  （?template=release.md）を作ってマージすることで自動的に行われます。
-->
