<!--
  main -> release 用の PR テンプレート（配布リリースの公開用）。
  URL の末尾に ?template=release.md を付けると、このテンプレートで本文が埋まります。
  例) https://github.com/pinnkoro/TOSAddon/compare/release...main?template=release.md

  重要: この PR の本文が、そのまま GitHub Release（移動タグ nexus_addons_p）の
  リリースノートになります（.github/workflows/release-nexus.yml が release への
  push を検知して公開）。マージすると nexus_addons_p-<version>.ipf が添付されます。

  日本語 -> 한국어 -> English の順に同じ内容を書きます。まず日本語セクションを
  書き上げてから、それを訳して韓国語・英語に反映してください（3 言語で項目数と
  順序を揃える。片方だけ項目が増減していないか公開前に確認）。
  アドオン名（Indun Panel など）とバージョン番号は訳さず原文のまま使います。
  該当する変更が無いサブセクションは、3 言語まとめて削除して構いません。

  公開前に、この説明用の HTML コメントブロックは削除してください。
-->

# 🛠️ Nexus Addons P v◯.◯.◯（v◯.◯.◯ → v◯.◯.◯）

## 🇯🇵 日本語

### ✨ 新機能・新対応

-

### 🐛 主なバグ修正

**＜アドオン名＞**

-

### 💾 安定化・内部改善（全体）

-

### 📥 導入方法

アドオンマネージャーから **Nexus Addons P** をインストールしてください。

---

## 🇰🇷 한국어

### ✨ 신기능・신규 대응

-

### 🐛 주요 버그 수정

**<애드온 이름>**

-

### 💾 안정화・내부 개선（전체）

-

### 📥 설치 방법

애드온 매니저에서 **Nexus Addons P** 를 설치해 주세요.

---

## 🌐 English

### ✨ New Features

-

### 🐛 Bug Fixes

**<Addon name>**

-

### 💾 Stability & Internal Improvements (overall)

-

### 📥 Installation

Install **Nexus Addons P** from the addon manager.

<!--
  公開前チェック:
  - [ ] addons.json の fileVersion が今回のバージョンと一致している
  - [ ] nexus_addons_p/ 直下に最新版 .ipf が1つだけある（旧版は _old/ へ移動済み）
  - [ ] main に必要な変更が全て入っている（この PR は main -> release）
  - [ ] 日本語 / 한국어 / English の 3 セクションで項目数と順序が揃っている
-->
