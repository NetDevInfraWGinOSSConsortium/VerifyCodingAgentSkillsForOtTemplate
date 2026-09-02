---
name: opentouryo-richclient-async
description: "OpenTouryo のリッチクライアント（Windows Forms / WPF デスクトップ）から B層を非同期に呼び出す。MyBaseAsyncFunc（Touryo.Infrastructure.Business.RichClient.Asynchronous）を使い、af.Parameter に引数を渡し、af.AsyncFunc デリゲートで副スレッド側の処理（CallController.Invoke / DoBusinessLogic による B層呼び出し）を、af.SetResult デリゲートで主スレッド側の結果表示（UI 更新）を実装し、af.Start() / StartByThreadPool() で起動する。副スレッドは画面メンバに触れない・主スレッドは UI 更新できる、という分界、画面ロックとスレッド数管理、業務例外（ErrorFlag）と例外（retVal is Exception）の受け取りを扱う。非同期呼び出し / 非同期 / 別スレッド / UI をブロックしない / MyBaseAsyncFunc / AsyncFunc / SetResult / リッチクライアント / WinForms / WPF で B層を非同期に呼ぶ 作業のときに使う。正式名は「非同期呼出フレームワーク」。※別物：非同期イベント・フレームワーク（AsyncEventFx＝組込系 IPC）・非同期処理サービス（別リポジトリ AsynchronousProcessingService＝多重度/リトライ/結果通知）はこのスキルの対象外。同期呼び出しは opentouryo-p-call-business。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# リッチクライアントの非同期呼び出し（正式名：非同期呼出フレームワーク）

> 📋 **コピー元スニペット**：`references/snippets.md`（MyBaseAsyncFunc・AsyncFunc/SetResult/ChangeProgress・クラス化版・分界。実装時はここから写す）。

## このスキルの適用範囲

**デスクトップ（Windows Forms / WPF）で、UI を固めずに B層を呼ぶ。**
`MyBaseAsyncFunc` を使う。

- 同期呼び出し → `opentouryo-p-call-business`
- 画面・イベント → `opentouryo-layer-p-winforms-screen` / `-event`（WPF は素の `Window`）

**リッチクライアントの唯一の非同期手段。** 2層C/S（`BaseLogic2CS`）には `DoBusinessLogicAsync`
が無い（`opentouryo-p-call-business`）。長い処理で UI を固めたくないときはこれを使う。
**WPF はこれを使える**（WPF は P層フレームワークを持たないが、非同期呼び出しは別機構）。実クラスは `BaseAsyncFunc`（親クラス1）＋`MyBaseAsyncFunc`（親クラス2）。APM/EAP パターン・`Control.Invoke`/`Dispatcher.Invoke` で UI 反映。

> **★ 「非同期」3つを混同しない**（正式名で区別）：
> - **①非同期呼出フレームワーク**＝**このスキル**（`BaseAsyncFunc`/`MyBaseAsyncFunc`。リッチクライアントから B層を非同期呼出）。
> - **②非同期イベント・フレームワーク**＝**組込系**（`AsyncEventFx`。デバイスドライバ通信・IPC・名前付きパイプ・メモリマップト共有メモリ。サンプル `AsyncEvent_sample`）。**別物・このスキルの対象外**。
> - **③非同期処理サービス**＝多重度/リトライ/結果通知・RDB キューテーブル・**別リポジトリ**（[AsynchronousProcessingService](https://github.com/OpenTouryoProject/AsynchronousProcessingService)・v02-30 分割）。**別プロダクト**。

## 副スレッドと主スレッドの分界（最重要）

```
af.AsyncFunc  … 副スレッドで走る。★画面メンバに触らない。B層を呼ぶのはここ
af.SetResult  … 主スレッドで走る。★UI を更新できる。結果表示はここ
```

**この2つを取り違えると、UI 更新が反映されない／クロススレッド例外になる。**

## 実装パターン

イベントハンドラ（Form / Window）に書く。**`this` は Form / Window。** 手順（**コードは `references/snippets.md`**）：

1. `MyBaseAsyncFunc af = new MyBaseAsyncFunc(this)`。
2. `af.Parameter` に引数を渡す（UI 値は主スレッドで退避）。
3. `af.AsyncFunc`＝副スレッド。★画面メンバに触らない。`CallController.Invoke` はここ（`CallController` は副スレッド内で生成）。
4. `af.SetResult`＝主スレッド。`retVal is Exception` 判定 → `ShowErrorMessageWin`、`ErrorFlag` 判定 → UI 更新。
5. `af.Start()`（実行中なら false）。

`using Touryo.Infrastructure.Business.RichClient.Asynchronous;`（`MyBaseAsyncFunc`）。
B層呼び出しはローカルなら `DoBusinessLogic`、3層（Web サービス越し）なら
`CallController.Invoke`（`opentouryo-transmission`）。上の例は 3層（`CallController.Invoke`）。
**リモート呼び出しは net48 専用**（`net10.0` では未実装。`opentouryo-transmission` 参照）なので、
core のデスクトップでは非同期処理の中身をローカルの `DoBusinessLogic` にする。

## 結果と例外の受け取り

`SetResult` の引数 `retVal` に、`AsyncFunc` の戻り値か**発生した例外**が入る。

| `retVal` | 意味 |
| --- | --- |
| 戻り値クラス（`ErrorFlag = false`） | 正常 |
| 戻り値クラス（`ErrorFlag = true`） | 業務例外（`opentouryo-exception`） |
| `Exception` | システム例外・その他の例外 |

**`retVal is Exception` を必ず判定する。** 副スレッドで出た例外はここに渡ってくる。

## 起動と画面ロック

| メソッド | 内容 |
| --- | --- |
| `af.Start()` | 非同期実行を開始。**別の非同期処理が実行中なら `false`** |
| `af.StartByThreadPool()` | スレッドプールで実行するバリアント |

**画面ロックとスレッド数管理をフレームワークが行う。** 実行中は画面がロックされ、
`Start()` は多重起動を弾く。スレッド数は `app.config` に定義する。

進捗表示は `af.ExecChangeProgress(...)`、非同期メッセージボックスは
`af.ShowAsyncMessageBoxWin(...)` / `ShowAsyncMessageBoxWPF(...)`。

## 派生クラスに処理を書く方法

`AsyncFunc` を匿名デリゲートではなく**クラスに書く**こともできる（`MyBaseAsyncFunc` を継承・`AsyncFuncDelegate`。
メンバ変数を引数代わりに使える。VB は匿名関数不可なのでこちら。派生内は `this.thisWinForm`/`this.thisWPF` で
コントロール参照）。**コードは `references/snippets.md`**。

## やってはいけないこと

- **`AsyncFunc`（副スレッド）で画面メンバに触る** — クロススレッドになる。UI 値は主スレッドで
  退避してから渡す（オブジェクトはクローンする）
- **UI 更新を `SetResult` 以外に書く** — 結果表示・フォーカス移動は `SetResult`（主スレッド）で
- **`CallController` を主スレッドで作って副スレッドで使い回す** — スレッドセーフでない。
  `AsyncFunc` 内で生成する
- **`SetResult` で `retVal is Exception` を判定しない** — 副スレッドの例外を取りこぼす
- **`Start()` の戻り値を無視する** — `false` は多重起動（別の非同期処理が実行中）
- **`UOC_Finally`（非同期側の最終処理）内で `Control.Invoke` / `Dispatcher.Invoke`（同期）を呼ぶ**
  — デッドロックの原因（クリティカルセクション内のため）
