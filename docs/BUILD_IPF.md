# アドオン .ipf のビルド方法

このリポジトリのアドオン(`nexus_addons_p` など)を配布用 `.ipf` にする手順をまとめる。
GUI(IPFSuite)を使う方法と、スクリプトで自動生成する方法の 2 通りを載せる。

---

## 1. 前提: 配布 .ipf の中身

配布用 `.ipf` は **2 層構造**:

1. **平文コンテナ** … アドオンフォルダ配下のファイル(`.lua` / `.xml` / `_conclude.lua`)を
   それぞれ raw deflate 圧縮して 1 つにまとめたもの
2. **PKware 暗号化** … 上をさらに暗号化したもの(これが配布形式)

`nexus_addons_p` の場合、コンテナには次の 3 ファイルが入る:

```
_nexus_addons_p/_nexus_addons_p.lua              ← 生成物(.gitignore)
_nexus_addons_p/_nexus_addons_p.xml              ← 手書き
_nexus_addons_p/_nexus_addons_p_conclude.lua     ← 生成物(.gitignore)
```

> **重要**: `.lua` 2 ファイルは **`nexus_addons_p/src/**` を連結した生成物**（source of
> truth は `src/`）。編集は `src/` 側で行い、`docs/bundle_from_src.py` で再生成する。
> 設計と分割の詳細は [REFACTOR_SPLIT_DESIGN.md](REFACTOR_SPLIT_DESIGN.md) を参照。

---

## 2. 必要なツール

| ツール | 場所 | 用途 |
| --- | --- | --- |
| `build_addon_ipf.py` | 本フォルダ `docs/` | 平文コンテナの生成 + 暗号化(方式 B。**これだけで完結する**) |
| `ipf_crypt.py` | 同上 | PKware 暗号化 / 復号の実装本体 |
| `IPFSuite.exe` | `$TOOLS_DIR` | GUI でコンテナを作る(方式 A。今は使わなくてよい) |
| `ipf_unpack.exe` | 同上 | decrypt / extract(**パック機能は無い**)。§4-1 の突き合わせ用 |
| `tos_extract.py` | TosSukillSimulator の `tools/` | 検証時に中身を展開して確認(任意) |

**暗号化に外部ツールは要らない**。以前は `ipf_unpack.exe <file> encrypt` を手で
叩く必要があったが、[ipf_crypt.py](ipf_crypt.py) が同じ出力を生成する
(配布中の `_nexus_addons_p-⛄-v1.0.2.ipf` を現 src から再生成して**バイト単位で一致**することを確認済み)。
アドオンを個別配布する構想では 1 リリースで `.ipf` を何十個も作るので、
ここが手作業だと回らない。詳細は [PER_ADDON_RELEASE_DESIGN.md](PER_ADDON_RELEASE_DESIGN.md) §3-6。

`$TOOLS_DIR` はリポジトリ外部の IPF ツール置き場(各自の環境で用意する)。
§4-1 の突き合わせを行うときだけ必要:

```bash
export TOOLS_DIR="/path/to/TOSAddon_Tools/workspace"   # 例: Git Bash なら /c/... 形式
```

Python は python.org 版(`Python312`)を使う(uv 同梱ビルドは避ける。詳細は個人メモ参照)。

---

## 3. ビルド手順

どちらの方式でも **「(src → bundle を生成) → 平文コンテナを作る → 暗号化する」** の流れ。

### 方式 B: スクリプトで自動生成(推奨・CI 化可能)

```bash
# 0) src -> bundle(.lua 2ファイル)を生成
#    (nexus_addons_p/src/** を manifest 順に連結。生成物は .gitignore 済み)
#    生成時に golden sha256 照合 + manifest 脱落チェックが走る。sha が合わないと失敗。
#    アドオンを意図的に変更した場合のみ golden を更新: python docs/bundle_from_src.py --bless
#    生成せず再現性だけ確認: python docs/bundle_from_src.py --check
python docs/bundle_from_src.py

# 1) 平文コンテナ + 暗号化 を一度に行い、配布形式の .ipf を出す(⛄ = U+26C4)
#    --require で生成物(bundle .lua)の同梱を必須化。手順 0 を飛ばして bundle 未生成のまま
#    詰めると本体を欠いた壊れた .ipf ができるので、不在なら失敗させる。
python docs/build_addon_ipf.py ./nexus_addons_p _nexus_addons_p \
    "nexus_addons_p/_nexus_addons_p-⛄-vX.Y.Z.ipf" \
    --require _nexus_addons_p/_nexus_addons_p.lua,_nexus_addons_p/_nexus_addons_p_conclude.lua \
    --encrypt
```

平文コンテナのまま確認したいときは `--encrypt` を外す。後から変換もできる:

```bash
python docs/ipf_crypt.py encrypt <plain.ipf> <out.ipf>
python docs/ipf_crypt.py decrypt <dist.ipf> <plain.ipf>
python docs/ipf_crypt.py --self-test      # リポジトリ内の全 .ipf を往復検証(CI でも実行)
```

`build_addon_ipf.py` は zlib **level 6**(= IPFSuite と同一バイト)で圧縮し、
テーブル・footer を実物と同じ書式で生成する。IPFSuite で作ったものと
バイト単位で一致することを確認済み(§5)。

### 方式 A: IPFSuite(GUI)

1. `IPFSuite.exe` を起動し、新規アーカイブを作成
2. アドオンフォルダ(`_nexus_addons_p/`)を、内部パス `_nexus_addons_p/...` を保った状態で追加
   - 内部の pack 名フィールドは `addon_d.ipf`(全アドオン共通の固定値)
3. `_nexus_addons_p-⛄-vX.Y.Z.ipf` の名前で保存(この時点では平文)
4. `encrypt.bat _nexus_addons_p-⛄-vX.Y.Z.ipf`(= `ipf_unpack.exe ... encrypt`)で暗号化

---

## 4. 検証(ビルド後に必ず実施)

`.ipf` はバイナリなので `git diff` では中身が見えない。

### 4-0. 復号不要のクイック検証(推奨・CI で自動実行)

```bash
python docs/verify_ipf.py
```

`.ipf` は「平文コンテナ → PKware 暗号化」の 2 層だが、暗号化されるのは**各ファイルの
データ本体だけ**で、末尾のファイルテーブルと footer は平文のまま残る。テーブルには
各ファイルの**平文 CRC32 と非圧縮 byte 数**が入っているので、src から期待される中身を
組み立てて突き合わせれば、復号鍵なしで「この .ipf は現 src から作られたか」を判定できる。

併せて、バージョンの三者一致(`00_header.lua` の `ver` / `addons.json` の `fileVersion` /
`.ipf` のファイル名)も検証する。`--content-only` / `--version-only` で片方だけも可。

> CRC32 は 32bit なので暗号学的な完全性保証ではない。ここで検出したいのは
> 「再ビルドし忘れ」であり、長さ一致と併せれば目的には十分。改竄検出には使わないこと。

このチェックは [ci.yml](../.github/workflows/ci.yml) の `ipf` ジョブが **採番を行う経路
(`release-prep/**` の PR / `main` → `release` の PR / `release` への push)でのみ**
自動実行する。通常の `main` の PR では `.ipf` を作り直さない運用なので、そこで回すと
恒常的に赤くなるため。

### 4-1. 復号して中身を突き合わせる(バイト単位で確認したいとき)

**復号 → 展開してソースと比較**する。

```bash
# 生成した .ipf を作業コピー(元ファイルは書き換えないこと。decrypt/extract は破壊的)
cp "nexus_addons_p/_nexus_addons_p-⛄-vX.Y.Z.ipf" /tmp/verify.ipf

# decrypt → extract。extract は「カレントディレクトリ/extract/<packname>/<内部パス>」に出す
cd "$TOOLS_DIR"
./ipf_unpack.exe /tmp/verify.ipf decrypt
./ipf_unpack.exe /tmp/verify.ipf extract lua xml
# → 出力先: ./extract/addon_d.ipf/_nexus_addons_p/_nexus_addons_p.lua など

# 元ソースと一致するか比較
cmp ./extract/addon_d.ipf/_nexus_addons_p/_nexus_addons_p.lua \
    <repo>/nexus_addons_p/_nexus_addons_p/_nexus_addons_p.lua
```

3 ファイルとも元ソースと一致すれば OK。`tos_extract.py`(IPF/IES リーダー)で
Python から往復検証してもよい。

---

## 5. なぜ level 6 なのか(バイト一致の根拠)

- IPFSuite が使う deflate は **stock zlib の既定 level 6**。
- `build_addon_ipf.py` を level 6 にすると、既存の `_nexus_addons_p-⛄-v1.1.6.ipf` を
  同じソースから再生成したとき **MD5 完全一致**する(検証済み)。
- level 9 でも「有効な .ipf」ではあるが(ゲームは問題なく解凍する)、
  圧縮結果が変わるためバイト一致はしない。オリジナルのツールチェーンと
  完全一致させたいので level 6 を採用している。

---

## 6. コンテナ書式(リファレンス)

`_nexus_addons_p-⛄-v1.1.6.ipf` を解析して確定した仕様:

```
[ファイルデータ領域]   各ファイル: raw deflate(level 6) を順に連結
[ファイルテーブル]     エントリを連結:
    path_len       u16
    checksum       u32   ← 平文(解凍後データ)の CRC32
    comp           u32   ← 圧縮後サイズ
    uncomp         u32   ← 元サイズ
    data_off       u32   ← ファイルデータ領域内のオフセット
    packname_len   u16
    packname       bytes ← 常に "addon_d.ipf"
    path           bytes ← 例 "_nexus_addons_p/_nexus_addons_p.lua"(区切りは "/")
[footer 24 バイト]
    file_count             u16
    table_off              u32   ← ファイルテーブル先頭オフセット
    0                      u16
    最終ファイルの data_off u32
    "PK\x05\x06"           4 バイト(シグネチャ)
    0                      u32
    0                      u32
```

暗号化は PKware(ZIP 伝統暗号)を **偶数インデックスのバイトのみ**に適用する変種。
footer 末尾 2 つの u32 が 0 のため、リーダー側は「暗号化あり」と判定して復号する。

---

## 7. リリース手順(まとめ)

> **1〜2 は通常の開発 PR(-> main)で行い、3〜5 の採番と .ipf の差し替えは公開直前の
> `release-prep/vX.Y.Z` ブランチでまとめて行う。** main だけ先に採番すると、
> アドオンマネージャーが main の `fileVersion` から組み立てるアセット名が Release 側に
> まだ無く、公開までの間だれもインストール／更新できなくなる(CI の `version-freeze`
> ジョブが先行採番を落とす)。詳細は [CLAUDE.md](../CLAUDE.md) を参照。

1. ソース(`nexus_addons_p/src/**` の該当アドオンファイル)を編集
   - 新規アドオン追加時は `src/addons/<key>/<key>.lua` 追加 + `src/core/10_registry.lua` に登録 +
     `src/build_manifest.json` の `targets` に連結順を追記(追記漏れは脱落チェックで即エラー)
   - アドオンは 1 つ 1 フォルダ。同じフォルダに利用者向けの `README.md` も置く
     (`.lua` 以外は脱落チェックの対象外なので、ビルドには影響しない)
2. `python docs/bundle_from_src.py --bless` で golden sha を更新(アドオンを変更したので必須)
   → `python docs/bundle_from_src.py` で bundle(.lua)を再生成 → 方式 B で `.ipf` を生成 → §4 で検証
3. 旧版 `.ipf` を `nexus_addons_p/etc/` へ移動(最新版だけをアドオン直下に置く慣習)
4. 新版を `nexus_addons_p/_nexus_addons_p-⛄-vX.Y.Z.ipf` に配置
5. `addons.json` の該当アドオンの `fileVersion` を更新
6. コミット & プッシュ

---

## 8. ゲーム内での反映・テスト

1. 生成した `.ipf` を
   `C:\Program Files (x86)\Steam\steamapps\common\Tree of Savior (Japanese Ver.)\data\`
   にコピー
2. `data\` に古い `_nexus_addons_p-⛄-*.ipf` があれば削除(バージョン競合防止)
3. クライアントを**再起動**(`.ipf` は起動時にマウントされるため、差し替え反映には再起動が必要)

> Lua の静的構文チェックはクライアント同梱の LuaJIT が実行ファイルに静的リンクされて
> いるため単体では行えない。必要なら WSL に `luajit` を入れてチェックする。
