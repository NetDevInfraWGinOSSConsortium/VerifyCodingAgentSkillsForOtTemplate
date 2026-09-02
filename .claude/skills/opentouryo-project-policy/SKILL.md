---
name: opentouryo-project-policy
description: "OpenTouryo を使うプロジェクト固有の方針を確認する。親クラス2（業務フレームワーク）の実装が決める仕様（MyUserInfo が持つ項目、メッセージの %1/%2 置換を行うか、User 分離レベルの振替先、接続文字列のキーと DBMS、UOC_ABEND での例外の振替、ACCESS / SQLTRACE ログの書式、追加された接頭辞）を、そのソース（MyFcBaseLogic / MyUserInfo / MyBaseController / MyBaseDao など Touryo.Infrastructure.Business）から読み取る手順を扱う。あわせて、コードに無く聞くしかない運用ルール（OPERATION ログの書式、イベントログの使いどころ）も扱い、ソースが提供されていない場合や運用ルールを決められない場合に纏め者へ投げる質問の作り方を示す。このプロジェクトではどうなっているか / 親クラス2 の挙動 / 業務フレームワークの実装 / プロジェクト方針 / 運用ルール / 書式の標準 / 纏め者に確認 が分からず実装を進められないときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# プロジェクト方針（親クラス2 の挙動）の確認

> 📋 **参照スニペット**：`references/snippets.md`（ソースを読むときの見どころ断片・纏め者への質問テンプレ）。

## このスキルの適用範囲

**「このプロジェクトではどうなっているか」が分からないと先に進めないときに使う。**

OpenTouryo には**フレームワークが決めず、親クラス2（業務フレームワーク）の実装が決める**
仕様がある。既定のテンプレートは付いてくるが、**纏め者が書き換える前提**なので、
テンプレートの値をそのまま「このプロジェクトの仕様」として扱ってはならない。

**推測で書かない。** 確認するか、人に聞く。

- **具体的タスク無しで起動されたら**（検証実行など）、確認したい項目をユーザに尋ねるか取り下げる（空振りで ③ テンプレを出さない）。
- **確認できた事実は残す**：確定した親クラス2 の仕様（未改変・`User`→`ReadCommitted` 等）は **repo 直下 `PROJECT-POLICY.md`
  （コミット・全エージェント可視）**へ記録し、次タスクで再確認を省く（**AGENTS.md はインストーラ再生成で上書き・`SETUP-CHANGES.md`
  はマシン変更用**なので不可。**Claude 固有メモリはリポ外＝他エージェントから見えない**ので使わない）。

このスキルは親クラス2 を**読んで確認する側**（アプリ開発者向け）。親クラス2 を**カスタマイズする側**
（纏め者向け）は `opentouryo-base2-customize`。

## 何がプロジェクト依存か

**2種類ある。確認方法が違う。**

### A. 親クラス2 の実装が決める（コードで確認できる）

| 事項 | 既定のテンプレート | 関連スキル |
| --- | --- | --- |
| `MyUserInfo` が持つ項目 | `UserName` / `IPAddress` の2つだけ | `opentouryo-auth` |
| メッセージの `%1`/`%2` 置換 | **Web Forms のみ**実装がある | `opentouryo-message` |
| `User` 分離レベルの振替先 | `ReadCommitted` | `opentouryo-layer-b` |
| 接続文字列のキー（→ **config を先に見る**）/ DBMS 選択（→ 親クラス2） | キーは `ConnectionString_SQL` ほか＝config 直読み。DBMS は `actionType` 接頭辞ごとで**単一に決まらない** | `opentouryo-config` |
| `UOC_ABEND` での例外の振替 | 振替の IF 文は雛形のみ。一般例外はリスロー | `opentouryo-exception` |
| 事前定義された例外メッセージ | `SAMPLE_ERROR` のみ | `opentouryo-exception` / `opentouryo-message` |
| `ACCESS` / `SQLTRACE` ログの書式 | カンマ区切り | `opentouryo-logging` |
| 追加された接頭辞 | `PREFIX_OF_CHECK_BOX` のみ | `opentouryo-layer-p-webforms-event` |
| P層イベント対応の拡張 | `CheckBox` のみ追加 | `opentouryo-layer-p-webforms-event` / `-winforms-event` |
| Web API の認証方式 | 既定 `EnumHttpAuthHeader.None`（認証なし）。Bearer は JWT 検証の雛形のみ | `opentouryo-auth` |
| `MyParameterValue`/`MyReturnValue` の共通項目 | 既定は共通引数（ユーザ情報等）のみ | `opentouryo-p-call-business` |

### B. 運用ルール（コードに無い。聞くしかない）

**フレームワークもテンプレートも定めていない。読む対象が存在しない。**

| 事項 | 関連スキル |
| --- | --- |
| `OPERATION` ログの書式（項目と区切り） | `opentouryo-logging` |
| イベントログ（`CustomEventLog` / `SecurityEventLog`）の使いどころ | `opentouryo-logging` |

**「決まりが無い」＝「自分で決めてよい」ではない。** 纏め者に確認する（③ へ直行）。

## 手順

```
A（親クラス2 の実装が決める）
  ① 親クラス2 のソースを探す
       見つかった → ② 読む（確認地図）
       見つからない → ③ 纏め者への質問にする

B（運用ルール）
  → ③ へ直行（読む対象が無い）
```

### ① ソースを探す

**バイナリ提供が原則だが、提供され方はプロジェクトによる。** まず探す。
`opentouryo-project-setup` で構築したプロジェクトなら、置き場は同じレイアウトになる：

| 見る場所 | 中身 |
| --- | --- |
| `base2-overlay/Frameworks/Infrastructure/Business/` | **このプロジェクトが実際に変えた親クラス2**（修正差分だけ・コミット済み。まず読む）。`opentouryo-base2-customize` |
| 展開ツリー `Temp/OpenTouryo-<ref>/...` **または短ルート `C:\otr\OpenTouryo-<ref>\...`**（いずれも `root/programs/CS/Frameworks/Infrastructure/Business/`） | 親クラス2 の**元ソース**（既定値の確認用）。**どちらも使い捨て**（`.gitignore`／セッションでクリア）＝**ローカルにしか無い**（新規クローンには無い。短ルートは MAX_PATH 回避で `setup-build` が使う） |
| `OpenTouryoAssemblies/Build_*/OpenTouryo.Business*.dll` | **ビルド済みバイナリ**（ソースではない） |

**まず `base2-overlay/` を読む**（既定から何を変えたかが分かる）。そこに無い項目は既定のままなので、
元ソース（`Temp/` か `C:\otr\` の展開ツリー）で既定値を確認する。
**★ overlay 機構がある構成で該当クラスが overlay に無ければ、纏め者は未改変＝既定値がこのプロジェクトの仕様と確定してよい**
（「やってはいけないこと」の『既定値を仕様として書くな』の**明示例外**。ただし既定値の取得には元ソースが要る＝下記手順）。
**`base2-overlay/` 自体が無い（overlay 機構未使用＝DLL 参照のみ）構成も同様に未改変とみなす**（stock ビルドの既定値＝仕様。
厳密な改変有無は `build-ref.txt`／纏め者確認で担保）。

**★ 展開ツリーが無い（クローン直後・セッションでクリア済み等）＝最頻ケースの手順（DLL しか無くても従う）：**
1. `<ref>`（固定タグ）を突き止める。repo に記録があれば（`OpenTouryoAssemblies\build-ref.txt` 等のマニフェスト＝
   `opentouryo-project-setup-build` が残す）それを使う。**マニフェストは古い構築物には無いことがある**：その場合、展開ツリー
   `C:\otr\OpenTouryo-<ref>` が残っていれば**フォルダ名から `<ref>` を読める**。**それも無ければ纏め者/ユーザに聞く**（`develop` なら再現不可）。
2. 上流を取得：`https://github.com/OpenTouryoProject/OpenTouryo/archive/<ref>.zip` を展開し、
   **`root/programs/CS/Frameworks/Infrastructure/Business/`** を読む（② の確認地図はここからの相対）。
3. `<ref>` も取れず上流も見られないなら → ③ で纏め者に聞く。

上記レイアウトでないプロジェクトでは、ファイル名（`MyFcBaseLogic.cs` / `MyUserInfo.cs` /
`MyBaseController.cs` 等）でリポジトリ内を検索する。アセンブリは `Touryo.Infrastructure.Business`、
名前空間は `Touryo.Infrastructure.Business.*`（本家では `Frameworks/Infrastructure/Business/`）。

**`.dll` しか無くても即 ③ ではない**：上の上流取得（固定タグ ZIP）で既定値は読める。それも不可なら → ③ へ。

### ② 読む（確認地図）

**パスは ① で見つけた `Frameworks/Infrastructure/Business/` からの相対。** 見つけたファイルの中の「見どころ」を読む。

| 確認したいこと | ファイル | 見どころ |
| --- | --- | --- |
| `MyUserInfo` の項目 | `Util/MyUserInfo.cs` | プロパティの一覧 |
| `%1`/`%2` の置換 | `Presentation/MyBaseController.cs` | `UOC_ABEND(BusinessApplicationException, FxEventArgs)` の中の `Replace("%1", ...)` |
| `User` の振替先 | `Business/MyFcBaseLogic.cs` | `UOC_ConnectionOpen` の `if (iso == DbEnum.IsolationLevelEnum.User)` |
| DBMS 選択方式（接続文字列の**キー自体は config を先に見る**＝`opentouryo-config`） | `Business/MyFcBaseLogic.cs`（2CS は `…2CS.cs`） | `UOC_ConnectionOpen` の `parameterValue.ActionType.Split('%')[0]`（**PascalCase プロパティ**。grep 注意）による Dam 選択と `GetConnectionString("...")`。`ActionType` は自由文字列でフレームワークが読むのは `[0]` のみ＝DBMS は複数系統ありうる。**対応 Dam は `#if` でランタイム別**（OLE/ODB/ODP=net48・NPS=core） |
| 例外の振替・リスロー | `Business/MyFcBaseLogic.cs` | `UOC_ABEND` の3つのオーバーロード |
| `ACCESS` ログの書式 | `Business/MyFcBaseLogic.cs` | `UOC_PreAction` / `UOC_AfterAction` / `UOC_ABEND` の `LogIF` 呼び出し |
| `SQLTRACE` ログの書式 | `Dao/MyBaseDao.cs` | `UOC_PreQuery` / `UOC_AfterQuery` |
| 追加された接頭辞 | `Util/MyLiteral.cs` | `PREFIX_OF_*` 定数 |
| P層イベント対応の拡張<br>（対応コントロール・イベント） | `Presentation/MyBaseController.cs`<br>`RichClient/Presentation/MyBaseControllerWin.cs` | `addControlEvent()` に追加された結線（既定外があるか） |
| 認証・ユーザ情報の復元 | `Presentation/MyBaseController.cs` | `GetUserInfo()` |
| Web API の認証方式・ログ書式 | `Presentation/MyBaseAsyncApiController.cs`<br>（Core は `...Core.cs`） | `GetUserInfoAsync` の `EnumHttpAuthHeader` 分岐（Basic/Bearer/None）・`OnActionExecuting/Executed` の `ACCESS` ログ |
| 引数/戻り値に足した共通項目 | `Common/MyParameterValue.cs`<br>`Common/MyReturnValue.cs` | `Base*Value` に追加したプロパティ（全 B層で運ぶ共通引数・戻り値） |
| 非同期処理（リッチ）の共通挙動 | `RichClient/Asynchronous/MyBaseAsyncFunc.cs` | `UOC_*` の override・`CanOutPutLog`（ログ抑止） |
| サブシステム区分・独自メタ属性 | `Util/MySubsysInfo.cs`（`SubsysID` enum）<br>`Util/MyAttribute.cs`（`MyAttributeA/B/C`） | 案件で足したサブシステム区分・独自属性の項目 |
| 事前定義された例外メッセージ | `Exceptions/MyBusinessApplicationExceptionMessage.cs`<br>`Exceptions/MyBusinessSystemExceptionMessage.cs` | 定義済みの `messageID` プロパティ（`.resx` 対応。纏め者が採番） |

P層は処理方式ごとにファイルが違う。**使っている方式のものを読む。**

| 処理方式 | ファイル |
| --- | --- |
| Web Forms | `Presentation/MyBaseController.cs` |
| ASP.NET MVC | `Presentation/MyBaseMVController.cs` |
| ASP.NET Core MVC | `Presentation/MyBaseMVControllerCore.cs` |
| Web API（net48） | `Presentation/MyBaseAsyncApiController.cs` |
| Web API（Core） | `Presentation/MyBaseAsyncApiControllerCore.cs` |
| Windows Forms | `RichClient/Presentation/MyBaseControllerWin.cs` |

**★ 上表で `Business/MyFcBaseLogic.cs` を指す4行（`User` 振替・DBMS 選択・例外振替・`ACCESS` ログ）は、2層C/S では
同名メソッドを持つ `RichClient/Business/MyFcBaseLogic2CS.cs` を読む**（構成が 2CS なら `MyFcBaseLogic.cs` ではなくこちら。
分離レベル/トランザクション/ロールバック挙動が違う＝`opentouryo-base2-customize`）。**片方だけ読んで結論しない。**

**`MyBaseLogic` / `MyBaseLogic2CS` は非推奨クラス。** `grep` で先にヒットしがちだが、
読むのは `MyFcBaseLogic` / `MyFcBaseLogic2CS`（`AGENTS.md` の非推奨一覧を参照）。

### ③ 纏め者への質問にする

**ソースが読めないなら、答えを持っているのは纏め者（親クラス2 を整備する側）だけ。**
勝手に決めず、**確認事項を質問の形にまとめて人へ渡す。**

**作業を止めて質問を出す。** 回答は人がプロンプトで指示する。

質問は**答えやすい形**にする。「どうなっていますか」ではなく、**既定値を示して差分だけ聞く。**
**質問テンプレート（`MyUserInfo`・`%1`/`%2`・`IsolationLevelEnum.User`・`UOC_ABEND`・`OPERATION` ログ・
`CustomEventLog`/`SecurityEventLog` を既定値付きで聞く形）は `references/snippets.md`** にある。コピーして使う。

**聞くのは、その作業に必要な項目だけ。** 全部聞く必要はない。

**★ 質問相手も居ないとき（無人の自動実行など）のフォールバック。** 止めて質問しても回答が得られないなら、
**親クラス2 の実装がどちらでも正しくなる、実装非依存の安全側に倒す**。これは「既定値を仕様と決めつける」（下記・禁止）とは別で、
**確認できるかどうかに結果が左右されない書き方を選ぶ**こと。例：`%1`/`%2` の置換有無が不明 → 置換に依存しない
**完成文でメッセージ定義**（`opentouryo-message`）。**選んだ前提と理由は記録**し（`PROJECT-POLICY.md` 等）、後で纏め者がレビューできるようにする。

## やってはいけないこと

- **既定のテンプレートの値を「このプロジェクトの仕様」として書く** — 纏め者が変えている
  前提の箇所がある。確認するか聞く
- **「決まりが無い」から自分で決める** — B（運用ルール）は**決まりが無いのではなく、
  こちらが知らないだけ**。書式や使いどころを勝手に発明しない
- **既存コードでの使われ方から結論を出す** — 手掛かりに留める。
  **「使われていない」は「できない」の根拠にならない**（単に使っていないだけかもしれない）
- **親クラス2 のソースが読めたので修正する** — 読むためであって、修正してよいという意味ではない
  （`AGENTS.md` の「クラスの階層と修正可否」参照）
- **分からないまま実装を進める** — 止めて質問を出す
- **纏め者に確認せずに親クラス2 を書き換えて辻褄を合わせる** — 修正対象ではない
- **`MyBaseLogic` / `MyBaseLogic2CS` を読んで「既定の挙動」と判断する** — 非推奨クラス。
  `MyFcBaseLogic` / `MyFcBaseLogic2CS` を読む
