#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""リリースノートの日本語セクションだけを Discord のチャンネルへ投稿する。

release-nexus.yml が、公開した直後に呼ぶ。リリースノートは main -> release の PR 本文で、
.github/PULL_REQUEST_TEMPLATE/release.md のとおり 日本語 -> 한국어 -> English の順に並ぶ。
ここから次の範囲だけを切り出す。

* 先頭の `# ` 見出し（`# 🛠️ Nexus Addons P v2.8.0（v2.7.0 → v2.8.0）`）
* `## 🇯🇵` の見出しの次の行から、最初の `---` か次の `## ` 見出しの手前まで
  （ただし毎回同じ文面の `### 📥 導入方法` の節は除く）

## Discord 側の制約

* **1 メッセージ 2000 文字まで。** 文字数は JavaScript の length（UTF-16 のコード単位）で
  数えられるので、絵文字は 2 文字になる。超える分は空行の区切りで複数に分けて送る。
  アドオン名の見出し（`**Mini Addons**`）や `###` だけが前のメッセージの末尾に取り残されない
  よう、見出しは直後の段落とくっつけてから詰める。
* **HTML コメントはそのまま文字として出る。** テンプレートの説明用コメントを消し忘れても
  流れないよう、先に取り除く。
* **`@everyone` などは本文に書いてあっても通知しない**（allowed_mentions を空にする）。
* **リンクのプレビューは出さない**（flags = SUPPRESS_EMBEDS）。
* **Markdown の画像（`![alt](url)` / `<img src>`）は表示されず、文字のまま出る。**
  本文からは抜き取り、本文を送り終えてから画像だけのメッセージ（embed の image）で送る。
  SUPPRESS_EMBEDS を付けると embed ごと消えるので、画像のメッセージには付けない。
  1 メッセージの embed は 10 個まで。Discord が URL を取りに行くので `http(s)` の絶対 URL だけ送る
  （相対パスは Release のページでも表示されないので、警告を出して飛ばす）。
* 既定の User-Agent（Python-urllib）だと Cloudflare に 403 で弾かれるので、明示する。

## 使い方

    python docs/post_release_discord.py notes.md --link <Release の URL> --dry-run
    python docs/post_release_discord.py notes.md --link <Release の URL>   # DISCORD_WEBHOOK_URL が要る
    python docs/post_release_discord.py --release v2.8.0 --dry-run      # 公開済みの版を取ってくる
    python docs/post_release_discord.py --self-test

--dry-run は送らずに分割結果を表示するだけなので、公開前の文面確認に使える。
--release は公開済みの Release から本文とページの URL を取ってくる（--link は要らない）。
Webhook の URL は環境変数 DISCORD_WEBHOOK_URL から読む（引数にすると履歴やログに残るため）。
**手元から実際に送るときは WSL で実行する**（Windows ホストはノートンが HTTPS を傍受する）。
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

LIMIT = 2000
EMBED_LIMIT = 10
# 毎回同じ文面の節。チャンネルで毎回読ませても情報が無いので、Discord には流さない
# （Release のページには残す。新しく入れる人はそちらから辿ってくる）。
SKIP_SECTION = "### 📥"
SUPPRESS_EMBEDS = 1 << 2
# alt は 1 段だけ [] の入れ子を許す（README の alt に「[AAS] 左クリック: 登録」のような書き方がある）
IMAGE_MD = re.compile(r'!\[(?:[^\[\]]|\[[^\[\]]*\])*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')
IMAGE_HTML = re.compile(r'<img\b[^>]*?\bsrc\s*=\s*["\']([^"\']+)["\'][^>]*>', re.I)
REPO = "pinnkoro/TOSAddon"
USER_AGENT = f"DiscordBot (https://github.com/{REPO}, 1.0)"


def discord_len(s: str) -> int:
    """Discord が数える文字数（UTF-16 のコード単位）。"""
    return len(s.encode("utf-16-le")) // 2


def extract_japanese(notes: str) -> str | None:
    """タイトルと日本語セクションを取り出す。日本語セクションが無ければ None。"""
    notes = re.sub(r"<!--.*?-->", "", notes, flags=re.S).replace("\r\n", "\n")
    lines = notes.split("\n")

    title = next((line.strip() for line in lines if line.startswith("# ")), None)
    start = next((i for i, line in enumerate(lines) if line.startswith("## 🇯🇵")), None)
    if start is None:
        return None

    body, skipping = [], False
    for line in lines[start + 1:]:
        if line.strip() == "---" or line.startswith("## "):
            break
        if line.startswith("### "):
            skipping = line.startswith(SKIP_SECTION)
        if not skipping:
            body.append(line)
    text = "\n".join(body).strip()
    if not text:
        return None
    return f"{title}\n\n{text}" if title else text


def extract_images(text: str) -> tuple[str, list[str]]:
    """画像の URL を出てきた順に抜き取り、本文から消す。画像だけだった行は行ごと消す。"""
    urls: list[str] = []

    def take(m: re.Match) -> str:
        urls.append(m.group(1))
        return ""

    lines = []
    for line in text.split("\n"):
        stripped = IMAGE_HTML.sub(take, IMAGE_MD.sub(take, line))
        if stripped != line and not stripped.strip(" \t-*>"):
            continue  # 画像しか無かった行（箇条書きの記号だけ残る行も含む）
        lines.append(stripped.rstrip())
    body = re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()
    return body, list(dict.fromkeys(urls))  # 同じ画像を 2 回貼っても 1 回だけ送る


def image_batches(urls: list[str]) -> list[list[str]]:
    """送れる URL（絶対 URL）だけを、1 メッセージの embed の上限ごとに分ける。"""
    ok = [u for u in urls if u.startswith(("https://", "http://"))]
    return [ok[i:i + EMBED_LIMIT] for i in range(0, len(ok), EMBED_LIMIT)]


def _is_heading(block: str) -> bool:
    """直後の段落と離したくない 1 行だけのブロック（### 見出し / **アドオン名**）。"""
    if "\n" in block:
        return False
    s = block.strip()
    return s.startswith("#") or bool(re.fullmatch(r"\*\*[^*]+\*\*", s))


def _hard_split(text: str, limit: int) -> list[str]:
    """1 ブロックが上限を超えるときの最後の手段。行で切り、それでも長い行は文字で切る。"""
    out, cur = [], ""
    for line in text.split("\n"):
        while discord_len(line) > limit:
            cut, n = 0, 0
            for ch in line:
                w = discord_len(ch)
                if n + w > limit:
                    break
                n += w
                cut += 1
            if cur:
                out.append(cur)
                cur = ""
            out.append(line[:cut])
            line = line[cut:]
        cand = f"{cur}\n{line}" if cur else line
        if discord_len(cand) > limit:
            out.append(cur)
            cur = line
        else:
            cur = cand
    if cur:
        out.append(cur)
    return out


def split_messages(text: str, limit: int = LIMIT) -> list[str]:
    """空行の区切りで、上限に収まるように詰めて分ける。"""
    blocks = [b.strip("\n") for b in re.split(r"\n\s*\n", text) if b.strip()]

    # 見出しは次のブロックとくっつける（見出しが続くときは全部まとめて次へ）。
    merged, pending = [], []
    for b in blocks:
        if _is_heading(b):
            pending.append(b)
            continue
        merged.append("\n\n".join(pending + [b]))
        pending = []
    if pending:
        merged.append("\n\n".join(pending))

    out, cur = [], ""
    for b in merged:
        pieces = [b] if discord_len(b) <= limit else _hard_split(b, limit)
        for p in pieces:
            cand = f"{cur}\n\n{p}" if cur else p
            if discord_len(cand) > limit:
                out.append(cur)
                cur = p
            else:
                cur = cand
    if cur:
        out.append(cur)
    return out


def build_messages(notes: str, link: str | None) -> tuple[list[str], list[list[str]]] | None:
    """(本文のメッセージ, 画像のメッセージごとの URL) を返す。日本語セクションが無ければ None。"""
    text = extract_japanese(notes)
    if text is None:
        return None
    text, urls = extract_images(text)
    for u in urls:
        if not u.startswith(("https://", "http://")):
            print(f"::warning::絶対 URL ではない画像は Discord へ送れないので飛ばした: {u}")
    if link:
        text += f"\n\n🔗 {link}"
    return split_messages(text), image_batches(urls)


def text_payload(content: str) -> dict:
    return {"content": content, "allowed_mentions": {"parse": []}, "flags": SUPPRESS_EMBEDS}


def image_payload(urls: list[str]) -> dict:
    return {"embeds": [{"image": {"url": u}} for u in urls], "allowed_mentions": {"parse": []}}


def post(webhook: str, body: dict) -> None:
    sep = "&" if "?" in webhook else "?"
    url = f"{webhook}{sep}wait=true"
    payload = json.dumps(body).encode("utf-8")

    for _ in range(5):
        req = urllib.request.Request(url, data=payload, method="POST", headers={
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
        })
        try:
            with urllib.request.urlopen(req, timeout=30):
                return
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")
            if e.code == 429:
                # 手前の Cloudflare が返す 429 は本文が HTML のことがあるので、ヘッダーへ逃がす。
                try:
                    wait = float(json.loads(detail).get("retry_after", 1))
                except (ValueError, AttributeError):
                    wait = float(e.headers.get("Retry-After") or 1)
                time.sleep(wait + 0.5)
                continue
            # URL（= 秘密）は出さない。Discord の応答本文だけ出す。
            raise RuntimeError(f"Discord が {e.code} を返した: {detail}") from None
    raise RuntimeError("Discord のレート制限が解けなかった")


def self_test() -> int:
    template = (
        "<!-- 説明 -->\n"
        "# 🛠️ Nexus Addons P v9.9.9（v9.9.8 → v9.9.9）\n\n"
        "## 🇯🇵 日本語\n\n### ✨ 新機能\n\n**Indun Panel**\n\n- 足した。<!-- 消し忘れ -->\n\n"
        "---\n\n## 🇰🇷 한국어\n\n- 추가했습니다.\n\n---\n\n## 🌐 English\n\n- Added.\n"
    )
    cases = []

    text = extract_japanese(template)
    cases.append(("日本語だけを切り出す",
                  text == "# 🛠️ Nexus Addons P v9.9.9（v9.9.8 → v9.9.9）\n\n"
                          "### ✨ 新機能\n\n**Indun Panel**\n\n- 足した。"))
    cases.append(("日本語セクションが無ければ None",
                  extract_japanese("Nexus Addons P v9.9.9\n") is None))
    cases.append(("CRLF でも切り出せる",
                  extract_japanese(template.replace("\n", "\r\n")) == text))
    cases.append(("--- が無くても次の ## で止まる",
                  extract_japanese("## 🇯🇵 日本語\n\n- a\n\n## 🇰🇷 한국어\n\n- b\n") == "- a"))
    cases.append(("導入方法の節は流さない（末尾）",
                  extract_japanese(template.replace(
                      "---", "### 📥 導入方法\n\nアドオンマネージャーから入れる。\n\n---", 1)) == text))
    cases.append(("導入方法の節は流さない（途中でも次の ### から戻る）",
                  extract_japanese("## 🇯🇵 日本語\n\n### 📥 導入方法\n\n- 入れる\n\n"
                                   "### 🐛 修正\n\n- 直した\n") == "### 🐛 修正\n\n- 直した"))

    cases.append(("絵文字は 2 文字で数える", discord_len("🛠️") == 3 and discord_len("あ") == 1))

    short = split_messages("a\n\nb")
    cases.append(("収まるなら 1 通", short == ["a\n\nb"]))

    para = "- " + "あ" * 900
    msgs = split_messages(f"**Indun Panel**\n\n{para}\n\n**Mini Addons**\n\n{para}\n\n{para}")
    cases.append(("上限を超えたら分ける", len(msgs) >= 2 and all(discord_len(m) <= LIMIT for m in msgs)))
    cases.append(("見出しは末尾に取り残されない",
                  all(not _is_heading(m.split("\n\n")[-1]) for m in msgs)))
    cases.append(("見出しは次の段落と同じ通に入る",
                  any(m.startswith("**Mini Addons**\n\n- ") or "\n\n**Mini Addons**\n\n- " in m
                      for m in msgs)))

    huge = split_messages("い" * 4500)
    cases.append(("改行の無い長文も文字で切る",
                  len(huge) == 3 and all(discord_len(m) <= LIMIT for m in huge)
                  and "".join(huge) == "い" * 4500))
    emoji = split_messages("😀" * 1500)
    cases.append(("サロゲートペアを割らない",
                  all(discord_len(m) <= LIMIT for m in emoji) and "".join(emoji) == "😀" * 1500))

    built = build_messages(template, "https://example.com/r")
    cases.append(("リンクを末尾に付ける",
                  built is not None and built[0][-1].endswith("🔗 https://example.com/r")))
    cases.append(("画像が無ければ画像のメッセージは無い", built is not None and built[1] == []))

    raw = "https://raw.githubusercontent.com/pinnkoro/TOSAddon/v9.9.9/nexus_addons_p/images/"
    body, urls = extract_images(
        "**Indun Panel**\n\n- 並びを変えた。\n\n"
        f"![一覧の画面]({raw}01.png)\n\n"
        f'- ボタンを足した。 ![ボタン]({raw}02.png "title")\n'
        f'- <img width="400" alt="設定" src="{raw}03.png" />\n\n'
        f"![同じ画像]({raw}01.png)\n\n![相対](images/04.png)\n\n次の段落。"
    )
    cases.append(("画像の URL を順に抜き取る（重複は 1 回）",
                  urls == [f"{raw}01.png", f"{raw}02.png", f"{raw}03.png", "images/04.png"]))
    cases.append(("画像だけの行は消え、文の後ろの画像は文を残す",
                  body == "**Indun Panel**\n\n- 並びを変えた。\n\n- ボタンを足した。\n\n次の段落。"))
    cases.append(("相対パスは送らない",
                  image_batches(urls) == [[f"{raw}01.png", f"{raw}02.png", f"{raw}03.png"]]))
    nested_body, nested_urls = extract_images(
        f"- 足した。\n\n![[AAS] 左クリック: 登録 の画面]({raw}05.png)\n")
    cases.append(("alt に [] を含む画像も抜き取る",
                  nested_body == "- 足した。" and nested_urls == [f"{raw}05.png"]))
    many = image_batches([f"{raw}{i}.png" for i in range(23)])
    cases.append(("画像は 10 枚ごとに分ける", [len(b) for b in many] == [10, 10, 3]))
    payload = image_payload([f"{raw}01.png"])
    cases.append(("画像のメッセージはプレビューを消さない",
                  "flags" not in payload
                  and payload["embeds"] == [{"image": {"url": f"{raw}01.png"}}]))

    bad = [label for label, ok in cases if not ok]
    for label in bad:
        print(f"NG self-test: {label}")
    if bad:
        return 1
    print(f"  OK self-test: {len(cases)} 件")
    return 0


def take_option(args: list[str], name: str) -> str | None:
    """`name 値` を args から取り除いて値を返す。"""
    if name not in args:
        return None
    i = args.index(name)
    if i + 1 >= len(args):
        raise SystemExit(f"{name} の後に値が要る")
    value = args[i + 1]
    del args[i:i + 2]
    return value


def fetch_release(tag: str) -> tuple[str, str]:
    """GitHub の Release（公開済み）から本文とページの URL を取る。"""
    url = f"https://api.github.com/repos/{REPO}/releases/tags/{tag}"
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": USER_AGENT,
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            data = json.load(res)
    except urllib.error.HTTPError as e:
        raise SystemExit(f"::error::Release {tag} を取得できない（{e.code}）。"
                         "版番号は v2.8.0 のように v 付きで渡す") from None
    return data.get("body") or "", data["html_url"]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    if "--self-test" in args:
        return self_test()

    dry_run = "--dry-run" in args
    link = take_option(args, "--link")
    tag = take_option(args, "--release")
    paths = [a for a in args if not a.startswith("--")]

    if tag:
        # 公開済みの Release から本文とページの URL を取る（手元から送り直すとき用）。
        notes, link = fetch_release(tag)
    elif len(paths) == 1:
        try:
            # utf-8-sig: PowerShell で保存すると先頭に BOM が付き、タイトルの `# ` を見落とすため
            with open(paths[0], encoding="utf-8-sig") as f:
                notes = f.read()
        except FileNotFoundError:
            print(f"::error::リリースノートのファイルが無い: {paths[0]}"
                  "（公開済みの版なら、ファイルの代わりに --release v2.8.0 のように版番号を渡す）")
            return 1
    else:
        print(__doc__)
        return 2
    built = build_messages(notes, link)
    if built is None:
        print("::error::リリースノートに「## 🇯🇵」の日本語セクションが無い。"
              "main -> release の PR を release.md のテンプレートから作ったか確認すること")
        return 1
    msgs, batches = built
    total = len(msgs) + len(batches)

    if dry_run:
        for n, m in enumerate(msgs, 1):
            print(f"===== {n}/{total}（{discord_len(m)} 文字）=====\n{m}\n")
        for n, b in enumerate(batches, len(msgs) + 1):
            print(f"===== {n}/{total}（画像 {len(b)} 枚）=====\n" + "\n".join(b) + "\n")
        return 0

    webhook = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
    if not webhook:
        print("::warning::DISCORD_WEBHOOK_URL が無いので Discord への投稿を省略した")
        return 0

    payloads = [(text_payload(m), f"{discord_len(m)} 文字") for m in msgs]
    payloads += [(image_payload(b), f"画像 {len(b)} 枚") for b in batches]
    for n, (body, what) in enumerate(payloads, 1):
        post(webhook, body)
        print(f"  投稿 {n}/{total}（{what}）")
        if n < total:
            time.sleep(1)  # 順番が入れ替わらないよう、1 通ずつ間を空ける
    return 0


if __name__ == "__main__":
    sys.exit(main())
