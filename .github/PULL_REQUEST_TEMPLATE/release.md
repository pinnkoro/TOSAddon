<!--
  main -> release 用の PR テンプレート（配布リリースの公開用）。
  URL の末尾に ?template=release.md を付けると、このテンプレートで本文が埋まります。
  例) https://github.com/pinnkoro/TOSAddon/compare/release...main?template=release.md

  重要: この PR の本文が、そのまま GitHub Release（移動タグ nexus_addons_p）の
  リリースノートになります（.github/workflows/release-nexus.yml が release への
  push を検知して公開）。マージすると nexus_addons_p-<version>.ipf が添付されます。
  下の <!-- --> コメントは公開前に消してください。
-->

## 🛠️ Nexus Addons アップデートまとめ（v◯.◯.◯ → v◯.◯.◯）

### ✨ 新機能・新対応

-

### 🐛 主なバグ修正

**＜アドオン名＞**

-

### 💾 安定化・内部改善（全体）

-

<!--
  公開前チェック:
  - [ ] addons.json の fileVersion が今回のバージョンと一致している
  - [ ] nexus_addons_p/ 直下に最新版 .ipf が1つだけある（旧版は etc/ へ移動済み）
  - [ ] main に必要な変更が全て入っている（この PR は main -> release）
-->
