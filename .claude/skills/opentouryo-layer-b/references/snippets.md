# B層 コードスニペット（コピー元）

出典：UserGuide 開発者編 §2・§4.2／纏め者編 §3、`Frameworks/Infrastructure/Business/Business/MyFcBaseLogic.cs`（実ソース）で裏取り。
**このファイルは on-demand 参照**（SKILL 本体のトークン予算外）。クラス名・メソッド名は任意に変更可。

## 業務コードクラスの骨格

```csharp
#region using
using System;
// ～
using ProjectName.Infrastructure.Business.Business;   // MyFcBaseLogic の名前空間
#endregion

/// <summary>LayerB の概要</summary>
public class LayerB : MyFcBaseLogic   // 「業務コード親クラス２」を継承する
{
}
```

## 業務処理メソッド（UOC_〈methodName〉）

`methodName`（引数クラスに指定）から `UOC_〈methodName〉` がレイトバインドで呼ばれる。

```csharp
/// <summary>btnButton1 に対応する業務処理</summary>
/// <param name="xParameter">引数クラス（業務ごとの型で受けられる＝キャスト不要）</param>
private void UOC_〈methodName〉(XParameterValue xParameter)
{
    // 戻り値クラスを生成し、先に this.ReturnValue へ設定する
    // （こうしておくと例外発生時にも戻り値が戻る）
    XReturnValue xReturn = new XReturnValue();
    this.ReturnValue = xReturn;

    // ↓業務処理 ------------------------------------------------
    // データアクセスクラスを生成（B層の Dam を渡す）
    LayerD myDao = new LayerD(this.GetDam());
    myDao.〈任意のメソッド〉(xParameter, xReturn);
    // ↑業務処理 ------------------------------------------------
}
```

## 引数クラス・戻り値クラス（業務用の定義）

```csharp
// 引数クラス：MyParameterValue（親クラス2）を継承
public class TestParameterValue : MyParameterValue
{
    public ShipperViewModel Shipper { get; set; }

    // Base のコンストラクタに引数を渡すために必要
    public TestParameterValue(
        string screenId, string controlId, string methodName, string actionType, MyUserInfo user)
        : base(screenId, controlId, methodName, actionType, user) { }
}

// 戻り値クラス：MyReturnValue（親クラス2）を継承
public class TestReturnValue : MyReturnValue
{
    public object Obj;
}
```

エラー系（`ErrorFlag`/`ErrorMessageID`/`ErrorMessage`/`ErrorInfo`）は `BaseReturnValue` が持つ＝定義し直さない。

## トランザクションと例外（重要）

- **ロールバックしたい → 業務内で例外をスローする。**
  - `BusinessApplicationException`（業務例外）：ロールバック後、**リスローされず** P層へ正常系の戻り値
    （`ErrorFlag=true`）として戻る。呼び出し側で `catch` しない（`opentouryo-exception`）。
  - `BusinessSystemException`（システム例外）／一般例外：ロールバック後、**リスローされる**。
- **正常終了（例外を投げない）→ 全てコミット**される。
- 戻り値は必ず `this.ReturnValue` に入れる（`return` で返さない）。

```csharp
// 業務例外（リトライ可能）をスロー ＝ ロールバックして P層へ ErrorFlag で戻す
// ★ コンストラクタは3引数（messageID, message, information）。詳細は opentouryo-exception
throw new BusinessApplicationException(
    MyBusinessApplicationExceptionMessage.SAMPLE_ERROR[0],   // messageID
    MyBusinessApplicationExceptionMessage.SAMPLE_ERROR[1],   // message
    "エラー情報");                                            // information（無ければ "" や "-"）
```

## 分離レベル

P層から `DoBusinessLogic(pv, iso)` の第2引数で渡る。**一律 `DbEnum.IsolationLevelEnum.User` を渡す**——
既定テンプレートで `ReadCommitted`（相当）へ振替（`MyFcBaseLogic.UOC_ConnectionOpen`。プロジェクト依存＝`opentouryo-project-policy`）。
