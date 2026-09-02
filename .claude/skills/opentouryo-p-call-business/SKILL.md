---
name: opentouryo-p-call-business
description: "OpenTouryo の P層から B層を呼び出す。引数クラス（MyParameterValue の派生）の組み立て、DoBusinessLogic / DoBusinessLogicAsync による呼び出し、分離レベル（IsolationLevelEnum）の指定、戻り値クラス（MyReturnValue の派生）と ErrorFlag による業務例外の受け取りを扱う。画面名・コントロール名・メソッド名・ユーザ情報の取り方が処理方式（Web Forms / Windows Forms / MVC）で違う点を表で示す。リッチクライアント（2層C/S）の手動トランザクション制御（CommitAndClose / RollbackAndClose、業務例外で自動ロールバックしない）も扱う。B層を呼ぶ / B層呼び出し / DoBusinessLogic / 引数クラス / 戻り値クラス / ErrorFlag / CommitAndClose / パラメータ値クラス を伴う作業のときに使う。B層の中身の実装は opentouryo-layer-b を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層から B層を呼び出す

> 📋 **コピー元スニペット**：`references/snippets.md`（インプロセス呼出・通信制御 Invoke・2CS 手動トランザクション。実装時はここから写す）。

## このスキルの適用範囲

**画面（P層）から業務ロジック（B層）を呼ぶ手順。** どの処理方式でも共通の型。

- 画面・イベントの実装 → `opentouryo-layer-p-webforms-screen` / `-event`、
  `opentouryo-layer-p-winforms-screen` / `-event`、`opentouryo-layer-p-mvc`
- B層の中身（業務コードクラス）→ `opentouryo-layer-b`
- 例外の型と受け取り → `opentouryo-exception`

## 呼び出しの4ステップ

```
① 引数クラスを生成する（画面名・コントロール名・メソッド名・ユーザ情報を渡す）
② B層を呼ぶ（**Web＝`DoBusinessLogic(pv, iso)` 直呼び／3層C/S＝`CallController.Invoke(論理名, pv)`**。下記「呼び出し経路の選択」）
③ 戻り値の ErrorFlag で業務例外を受け取る
④ リッチクライアント（2CS）だけ、CommitAndClose() で明示的にコミットする
```

①〜③の**コードは `references/snippets.md`**（引数クラス＝`new TestParameterValue(画面名, コントロール名,
"SelectCount"〔→ B層 `UOC_SelectCount`〕, actionType, ユーザ情報)` → 呼び出し（下記）→ `rv.ErrorFlag` 判定）。

## 呼び出し経路の選択（既定は処理方式で違う）

P→B には**2経路**があり、**既定は処理方式で決まる**（どちらが正しいかではない）。配布サンプルも両方ある（`sampleScreen`＝直呼び／`sampleScreen_cc`＝`CallController`）。

| 経路 | 既定の処理方式 | 分離レベル | 疎結合／WS 切替 |
| --- | --- | --- | --- |
| **`new LayerB().DoBusinessLogic(pv, iso)` 直呼び** | **Web（WebForms・MVC）** | **per-call で指定可**（`iso` 引数。同一プロセスでクライアント側が決める） | ✕（B層クラスへ直接参照） |
| **`CallController.Invoke(サービス論理名, pv)`** | **3層C/S（リッチクライアント／WS）** | **クライアントからは指定しない**（下記＝サーバ側で決める） | ○（論理名解決でインプロセス⇄WS をコード無変更で切替） |

- **`Invoke` に分離レベル引数が無いのは「制約」でなく設計。** 3層C/S ではP層（クライアント）とB層（サーバ）が分離するので、
  **分離レベルはサーバ側の関心事**。CallController／WS の入口は B層を常に **`iso=User`** で呼び（`CallController.cs` L366・
  `FxController.cs`・`WCFTCPSvcForFx.cs`）、実際の分離レベルは**サーバ側で決める**——親クラス2 `MyFcBaseLogic.UOC_ConnectionOpen` の
  `User` 振替（`opentouryo-project-policy`）、必要なら**属性ベースで B層クラス・メソッドに埋め込む**（`opentouryo-transaction-control`）。
- **Web でも `Invoke` を選べば**疎結合になり後で WS へ無変更で移せるが、その場合 per-call の `iso` は渡せない（サーバ側方式に従う）。
  `InvokeAsync` も同2引数。`opentouryo-transmission`。
- **★ 通信制御で3層構成を採るなら、後の物理分離に備えて実装先を分ける**：**B層・D層は `WSServer_sample` 側／
  型情報（引数・戻り値クラス＝`MyParameterValue`/`MyReturnValue` 派生）は `WSIFType_sample` 側**に置く
  （クライアントとサーバの**両方が参照する共有契約**なので別アセンブリに。型は `[Serializable]`＝WS 転送）。
  P層（クライアント）は共有アセンブリの型を参照し `Invoke` で呼ぶ。**2層（直呼び）は型も B/D もアプリ内**。
  実装配置の対比（3層／2層）とコードは `references/snippets.md`「3層構成での実装配置」。
  **★ 定義ファイル：`TMProtocolDefinition`＝クライアントのみ／`TMInProcessDefinition`＝クライアントとサーバの両方（リモート経路はサーバ側を引く）。サービス論理名を足したら両方に同じ `id` を登録する**（詳細＝`opentouryo-transmission`）。

## ① 引数クラスの組み立て（処理方式で違う）

**渡す値の取り方が処理方式ごとに違う。** ここだけが方式依存で、あとは共通。

| 引数 | Web Forms | Windows Forms（2CS） | MVC |
| --- | --- | --- | --- |
| 画面名 | `this.ContentPageFileNoEx` | `this.Name`（Form の Name） | `this.ControllerName` |
| コントロール名 | `fxEventArgs.ButtonID` | `rcFxEventArgs.ControlName` | `"-"`（固定） |
| メソッド名 | **文字列で明示** | **文字列で明示** | `this.ActionName`（自動） |
| ユーザ情報 | `this.UserInfo` | `MyBaseControllerWin.UserInfo`（**static**） | `this.UserInfo` |

**★ ユーザ情報（引数の `user`）は null 不可。** 親クラス2（例 `MyFcBaseLogic2CS.UOC_PreAction`）が内部でユーザ情報を参照するため、
`null` を渡すと `DoBusinessLogic` の中で `NullReferenceException` になる（実測）。実画面は上表の値（`this.UserInfo` や static の
`MyBaseControllerWin.UserInfo`＝既定値入り）を渡すので起きないが、**バッチ／テスト ハーネスなど画面外から B層を叩くときに踏む**（既定の `MyUserInfo` を渡す）。

**メソッド名が B層の振り分けキー。** B層（`MyFcBaseLogic`）が `"UOC_" + メソッド名` で
レイトバインドする。MVC はアクション名が自動で入るが、Web Forms / Windows Forms は
イベントハンドラ名と対応しないため**文字列リテラルで明示する**。綴りがズレると実行時に
見つからない（コンパイルは通る）。
**★ 既存の共有 LayerB に相乗りするなら、衝突しない UOC 名を渡す**（全フレームワーク共通）。特に **MVC は `this.ActionName` を自動で渡す**ので、汎用アクション名（例 `SelectCount`）だと**その LayerB の既存 `UOC_SelectCount(別の引数型)` にレイトバインドで飛び**、引数型不一致で失敗する＝**例外はフレームワークに捕捉され画面がメッセージ無しで再描画されるだけ**（500 にならず原因に辿りにくい・実測）。相乗り時は `MethodName` に**一意な UOC 名**（例 `SuppliersSelectCount`）を明示する。

引数クラス・戻り値クラスは `MyParameterValue` / `MyReturnValue` の派生として業務ごとに作る。

### actionType の使い方（DBMS 選択を含む）

`actionType`（コード例の第4引数）は**業務コードが自由に解釈する文字列**。
もともとは、`MyFcBaseLogic`導入以前の `MyBaseLogic` の B層ルート・メソッドで振り分け処理を
実装をするために使用していた。

意味はプロジェクトが決める。フレームワークの固定仕様ではない。

**ただし既定テンプレートの親クラス2（`MyFcBaseLogic.UOC_ConnectionOpen`）では、
`actionType.Split('%')[0]`（`%` 区切りの先頭）を DBMS コードとして読み、Dam と
接続文字列を選ぶ実装になっている。**

既定テンプレートを使うなら、先頭は DBMS コードにする。

| 先頭コード | DBMS / プロバイダ | 接続文字列キー |
| --- | --- | --- |
| `SQL` | SQL Server（既定） | `ConnectionString_SQL` |
| `ODP` | Oracle（ODP.NET） | `ConnectionString_ODP` |
| `ODB` / `MCN` / `NPS`(Core) / `OLE`(net48) | ODBC / MySQL / PostgreSQL / OLEDB | `ConnectionString_<コード>` |

**先頭以降のセグメントの意味はプロジェクト定義。** 

**`actionType.Split('%')[0]`（`%` 区切りの先頭）より後ろはサンプルの
B層コードが `switch` で分岐しているだけで、フレームワークの仕様ではない。**
実際のプロジェクトは独自の規約を定める（DBMS 単一なら `"SQL"` だけのことも多い）。
DBMS 選択も含め、親クラス2 は纏め者がカスタマイズできる（`opentouryo-project-policy`）。

## ② DoBusinessLogic と分離レベル

| メソッド | 用途 |
| --- | --- |
| `DoBusinessLogic(pv)` | 同期・既定の分離レベル |
| `DoBusinessLogic(pv, iso)` | 同期・分離レベル指定 |
| `DoBusinessLogicAsync(pv)` / `(pv, iso)` | 非同期（**2CS には無い**。リッチクライアントで非同期にしたいなら `opentouryo-richclient-async`） |

`iso` は `DbEnum.IsolationLevelEnum`。既定に委ねるなら `User`。値と意味は `opentouryo-layer-b`。

```csharp
// MVC の例（非同期）
TestReturnValue rv = (TestReturnValue)await layerB.DoBusinessLogicAsync(
    pv, DbEnum.IsolationLevelEnum.ReadCommitted);
```

## ③ 戻り値と業務例外

**業務例外（`BusinessApplicationException`）は例外では飛んでこない。** フレームワークが
捕捉し、戻り値の `ErrorFlag = true` に変換する。`try`/`catch` しない（`opentouryo-exception`）。

```csharp
if (rv.ErrorFlag)
{
    // rv.ErrorMessageID / rv.ErrorMessage / rv.ErrorInfo
}
```

システム例外・その他の例外は、そのまま飛んでくる（親クラス2 の `UOC_ABEND` が処理・振替）。

## ④ リッチクライアント（2CS）は手動トランザクション

**Windows Forms（`BaseLogic2CS` 系）だけ、コミットが手動。** Web / MVC は自動なので不要。

### なぜ違うのか

**アプリが Desktop 上のインスタンスとして動作するため、アプリごとのグローバルな
1トランザクションを使う設計。** 1プロセス = 1利用者で、分ける概念が無い。この前提から、
コネクションが `static`・コミットが手動・業務例外で自動ロールバックしない、がすべて導かれる。

| | Web / MVC（`BaseLogic`） | **Windows Forms（`BaseLogic2CS`）** |
| --- | --- | --- |
| コネクション | 呼び出しごとに開閉 | **グローバル（`static`）で使い回す** |
| 正常系のコミット | **フレームワークが自動** | **しない。手動で `CommitAndClose()`** |
| 業務例外のロールバック | **する** | **しない**（後述） |
| システム例外・その他の例外 | ロールバックする | ロールバックする |

### コミットは手動で呼ぶ

```csharp
LayerB layerB = new LayerB();
TestReturnValue rv = (TestReturnValue)layerB.DoBusinessLogic(pv, iso);
LayerB.CommitAndClose();   // ★ 明示的にコミットする。呼ばないと確定しない
```

`BaseLogic2CS` の `static` メソッド。

| メソッド | 内容 |
| --- | --- |
| `CommitAndClose()` | コミットしてコネクションを閉じる |
| `RollbackAndClose()` | ロールバックしてコネクションを閉じる |
| `ConnectionClose()` | コネクションを閉じる |

コネクションがグローバルなので、**複数の B層呼び出しを1トランザクションにまとめられる。**
その代わり閉じ忘れるとコネクションが残る（`NoTransaction` のときだけ `finally` で都度閉じる）。

### 業務例外で自動ロールバックされない

**アプリ全体で1トランザクションなので、フレームワークが勝手にロールバックできない。**
業務例外は「利用者がやり直せるエラー」で、そこで巻き戻すと積み上げた処理まで消える。

```csharp
if (rv.ErrorFlag)
{
    // 入力し直させて続行するなら、ロールバックしない
    // 取り消すなら明示的に呼ぶ
    LayerB.RollbackAndClose();
}
```

## B層クラスの継承元

| | 継承元 |
| --- | --- |
| Web Forms / MVC | `MyFcBaseLogic` |
| Windows Forms（2CS） | `MyFcBaseLogic2CS` |

**`MyBaseLogic` / `MyBaseLogic2CS` は非推奨。** 業務コードクラスの書き方自体は
どちらも同じ（`opentouryo-layer-b`）。違うのは継承元とトランザクション制御だけ。

## やってはいけないこと

- **業務例外を `try`/`catch` する** — 飛んでこない。戻り値の `ErrorFlag` で受ける
- **メソッド名（振り分けキー）を渡し忘れる／綴りをズラす** — 実行時に見つからない
- **2CS で `CommitAndClose()` を呼び忘れる** — 自動コミットされず確定しない
- **2CS で業務例外なら自動ロールバックされると考える** — されない。`RollbackAndClose()` を
  自分で判断する
- **Web / MVC で `CommitAndClose()` を呼ぶ** — 不要。フレームワークが自動でコミットする
- **`MyBaseLogic` / `MyBaseLogic2CS` を継承する** — 非推奨
