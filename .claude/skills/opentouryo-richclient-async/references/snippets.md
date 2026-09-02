# リッチクライアント非同期呼び出し コードスニペット（コピー元）

出典：UserGuide リッチクライアント編 §2、`Business/RichClient/Asynchronous/MyBaseAsyncFunc.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。Windows Forms / WPF 共通。

## 非同期で B層を呼ぶ（匿名デリゲート版）

```csharp
using Touryo.Infrastructure.Business.RichClient.Asynchronous;

private void UOC_btnASync_Click(RcFxEventArgs rcFxEventArgs)
{
    MyBaseAsyncFunc af = new MyBaseAsyncFunc(this);

    // ① 副スレッドで走る本体：★画面メンバに触らない。B層呼び出しはここ
    af.AsyncFunc = delegate(object param)
    {
        // CallController.Invoke / DoBusinessLogic で B層を呼ぶ
        af.ExecChangeProgress("進捗");   // 進捗報告（ChangeProgress へ）
        return result;                   // 戻り値は SetResult へ渡る
    };

    // ② 主スレッドで走る：★UI 更新はここ
    af.SetResult = delegate(object retVal)
    {
        if (retVal is Exception)
        {
            // 副スレッドで発生した例外はここに来る（取りこぼさない）
        }
        else
        {
            // 結果表示・フォーカス移動など
            this.BeginInvoke(new MethodInvoker(this.SetFocus));
        }
    };

    // ③ 進捗表示（主スレッド）
    af.ChangeProgress = delegate(object param) { /* 進捗UI */ };

    // ④ 起動（スレッド数上限に達すると false）
    if (af.Start())      // または af.StartByThreadPool()
    {
        // キューイングされた（BaseAsyncFunc.ThreadCount で確認可）
    }
}
```

## クラス化版（VB は匿名関数不可なのでこちら）

```csharp
public class AsyncFunc : MyBaseAsyncFunc
{
    public AsyncFunc(object _this) : base(_this) { }
    public object Exec(object param) { /* 副スレッド処理 */ return null; }
}
// 呼び出し側
AsyncFunc af = new AsyncFunc(this);
af.AsyncFunc = new BaseAsyncFunc.AsyncFuncDelegate(af.Exec);
```

## 分界と注意

- `AsyncFunc`（副スレッド）＝画面メンバに触れない。UI 値は主スレッドで取り、`af.Parameter` で渡す。
- `SetResult`（主スレッド）＝UI 更新・`retVal is Exception` 判定はここ。
- スレッド数は config `FxMaxThreadCount`。`UOC_Finally`（親クラス2）内で `Control.Invoke`/`Dispatcher.Invoke`（同期）を呼ばない（デッドロック）。

> 同期呼び出しは `opentouryo-p-call-business`。非同期側の共通処理（`UOC_Pre/After/ABEND/Finally`）は `opentouryo-base2-customize`。
