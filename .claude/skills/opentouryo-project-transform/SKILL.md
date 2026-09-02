---
name: opentouryo-project-transform
description: "OpenTouryo プロジェクトをセットアップ後に用途へ合わせて変形（リストラクチャ）する後工程。サブコマンド式：(1) minimize＝サンプル/テスト画面を除いて最小骨格化（testScreen・3Tier・デモ content 画面と専用 AppCode を削る。実使用のマスタ〔menu シェルや blank マスタ〕は名前が sample/test でも残す）、(2) ws-decouple＝WS 依存の切り離し（俗称2層化。3層画面・WSIFType/WSServer 参照・専用周辺コードの除去と CS0246 解消）。現行手順は WebForms_Sample 前提（実物で裏取り済み）。取得・ビルド・参照張り替え・config でソリューションを開ける状態にするのは opentouryo-project-setup、既存構成の上で新規に業務コードを書くのは各層スキル（opentouryo-layer-* ほか）。最小化 / 最小骨格 / テストコード除去 / サンプル画面削除 / 骨格化 / WS 依存を切り離す / 2層化 / 3層を削る / 不要な依存の削減 / サンプルの整理 / 変形 / リストラクチャ / CS0246 を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.2.0"
---

# プロジェクトの変形（セットアップ後のリストラクチャ）

<!-- 執筆者メモ（Claude Code は読み込み時に除去）：
     ディスパッチャ＝薄い受付。重い手順は references/<sub>.md（budget-free）へ。
     現状の subcommand は minimize（テスト除去・最小化）と ws-decouple（2層化）の2本。
     いずれも手順は WebForms_Sample 前提で裏取り済み。将来の変形（認証方式差し替え等）や
     MVC 等の未収録対象は、下記「未収録の対象が来たら」に従いベストエフォート→検証後に収録。
     net48↔core はランタイム別サンプルで対応＝サンプル選択（opentouryo-project-setup）の領分で対象外。 -->

## 適用範囲と実行タイミング

セットアップで**開ける状態にした**サンプルを、用途に合わせて**構成を削る／変える**とき。**利用者主導・任意**。
セットアップ直後に続けてでも、後日ソリューションを俯瞰してからでもよい（途中に割り込ませない）。

- ゼロから開ける状態にする（取得・ビルド・参照張り替え・config）→ `opentouryo-project-setup`
- 既存構成の上で新規に業務コードを書く → 各層スキル（`opentouryo-layer-*` ほか）

## サブコマンド（どれか1つを当てる）

| subcommand | 何をする（ゴール） | 詳細 | 主なトリガ |
| --- | --- | --- | --- |
| **`minimize`** | サンプル/テスト画面を除いて**最小骨格**へ | `references/minimize.md` | 最小化 / 最小骨格 / テストコード除去 / サンプル画面削除 / 骨格化 |
| **`ws-decouple`** | **WS 依存の切り離し**（俗称「2層化」） | `references/ws-decouple.md` | 2層化 / 3層を削る / WS 依存を切り離す / CS0246 |

- 関係：`ws-decouple` は**2層サンプル画面を残して WS だけ外す**。`minimize` は**サンプル画面ごと骨格まで落とす**（3層画面の除去も内包）。end-state が違う。
  **★ 両方を当てるなら `ws-decouple` の実行時確認を `minimize` より前に済ませる**（実測）。確認に使う伝送制御画面 `~/Aspx/sample/crud/sampleScreen_cc.aspx` は
  `minimize` の削除対象（`~/Aspx/sample/**`）にあり、後回しにすると**404 になるだけで「2層化が壊れた」のか「画面がもう無い」のか区別できない**。
- `/opentouryo-project-transform <sub>` の引数、または自動起動時は**タスク内容から subcommand を選び、該当 `references/<sub>.md` を読んでから**作業する。

## 現行の前提（裏取りの範囲）

両 subcommand とも、**具体手順は `WebForms_Sample` 前提**（実物で裏取り済み）。`MVC_Sample` も WS 依存を持つ
（`MVC_Sample.csproj` が `WSIFType_sample`/`WSServer_sample` を参照）＝ws-decouple の対象になり得るが、
**参照形態が違い**（WebForms＝ProjectReference / MVC＝DLL Reference の HintPath）**手順は未収録**。

## 未収録の対象が来たら（ベストエフォート＋断り）

1. **未収録である旨を先に断る**（例「MVC は手順未収録。一般原則からのベストエフォート」）。
2. **憶測で書かず実ソースで裏取りしながら進める**（実クローンあり＝`reference-csharp-source-mirror` の場所）。
3. **段階ビルドで検証**（`削る→再ビルド→CS0246 を上から潰す` loop がセーフティネット＝間違えればビルドが落ちて気づく）。
4. そこで得た手順は**勝手にスキルへ書かない**（配布物は裏取り済みのみ。検証後に纏め者が収録）。
5. **後戻りできず検証手段が無い破壊**はそのまま進めず確認する。

## 共通ポリシー（両 subcommand 共通）

- **基盤（`OpenTouryo.*` / `Frameworks/Infrastructure/*` の本体クラス）は触らない**＝本体・纏め者の領分（`opentouryo-project-policy`）。
  変形は**サンプル由来の業務コード側だけ**。**親クラス2（`My*`＝`MyBaseController` 等）のカスタマイズが要るなら
  `opentouryo-base2-customize`**（master ハンドラの扱いは `references/minimize.md`）。
- **まずビルドして現状把握**→**段階的に**：一気に消さず「削る→再ビルド→`CS0246`（型・名前空間が見つからない）等を潰す」を繰り返す。
- **複数行の一括置換前に改行コードを確認する**（実測）。サンプルの `.csproj` / `.config` は **LF**（GitHub ZIP 由来）のことがあり、
  **CRLF 前提の複数行ブロック置換はマッチせず失敗する**（単一行は通るので気付きにくい）。
- **非対話では削除とテキスト置換を別コマンドに分け、削除も1コマンド1対象に割る**（PowerShell/bash 共通・実測）。`Remove-Item`/`rm` と `/>` 等の断片を同一コマンドに
  混ぜる・**複数対象をまとめて削除**すると、安全ガードが「システムパス削除」と誤検知してコマンド全体がブロックされることがある。

## やってはいけないこと

- **基盤を改造して辻褄を合わせる**（纏め者・本体の領分）／**セットアップをここでやり直す**（それは `opentouryo-project-setup`）。
- **一括で大量に削ってからまとめてビルド**（依存を見失う。段階的に削って都度ビルド）。
- **名前の接頭辞で機械的に一括削除**する（`test*` / `sample*` でも**実使用のマスタ・足場**がある＝各 `references/` の「★トラップ」参照）。
