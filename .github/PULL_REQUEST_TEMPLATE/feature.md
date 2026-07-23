<!--
  feature ブランチ -> main 用の PR テンプレート。
  URL の末尾に ?template=feature.md を付けると、このテンプレートで本文が埋まります。
  例) https://github.com/pinnkoro/TOSAddon/compare/main...<ブランチ>?template=feature.md
-->

## 概要

<!-- 何を・なぜ変更したか（1〜3行） -->

## 対象アドオン

- アドオン名:

<!--
  バージョンはここでは上げません（採番は公開直前の release-prep/vX.Y.Z ブランチのみ）。
  main だけ先に採番すると、アドオンマネージャーが main の fileVersion から組み立てる
  アセット名が Release 側に無く、公開までの間だれもインストール／更新できなくなります。
  CI の version-freeze ジョブが変更を検出して落とします。
-->

## 変更内容

-

## 動作確認

<!-- ゲーム内での確認結果・確認できていない点など -->

## チェックリスト

- [ ] 編集は `nexus_addons_p/src/**` 側で行った（生成物の bundle `.lua` は直接編集していない）
- [ ] `python docs/bundle_from_src.py --bless` → `python docs/bundle_from_src.py` で bundle を再生成した
- [ ] **バージョン情報を変更していない**（`00_header.lua` の `ver` / `addons.json` の
      `fileVersion` / `.ipf` のファイル名。手元での確認は `python docs/check_version_freeze.py`）
- [ ] **`nexus_addons_p/README.md` の更新履歴に追記した**（`（次回リリース）` 見出しへ / CLAUDE.md ルール）

### 採番 PR（`release-prep/vX.Y.Z` -> main）のときだけ

- [ ] 版番号 3 箇所（`ver` / `fileVersion` / `.ipf` ファイル名）を揃えた
- [ ] `.ipf` を再ビルドし、`python docs/verify_ipf.py` で src との一致を確認した（`docs/BUILD_IPF.md` §4）
- [ ] 旧 `.ipf` を `nexus_addons_p/_old/` へ移動した
- [ ] 更新履歴の `（次回リリース）` 見出しを `vX.Y.Z` に確定させた

<!--
  配布（GitHub Release への公開）は main へマージした後、別途 main -> release の PR
  （?template=release.md）を作ってマージすることで自動的に行われます。
  採番 PR をマージしたら、間を空けずに公開 PR を出してください。
-->
