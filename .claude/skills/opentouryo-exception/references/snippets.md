# 例外 コードスニペット（コピー元）

出典：UserGuide 共通編 §2.3／纏め者編 §6.1、`Framework/Exceptions/*.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## コンストラクタ（実ソース確認済み）

```csharp
// 業務例外：エラー情報（information）を持つのはこの型だけ
new BusinessApplicationException(string messageID, string message, string information);
new BusinessApplicationException(string messageID, string message, string information, Exception innerException);
// システム例外
new BusinessSystemException(string messageID, string message);
new BusinessSystemException(string messageID, string message, Exception innerException);
// フレームワーク例外（フレームワークが検知した例外用。業務コードから通常スローしない）
new FrameworkException(string messageID, string message);
new FrameworkException(string messageID, string message, Exception innerException);
```

プロパティ：`messageID`（全型・**小文字始まり**）／`Message`（全型）／`Information`（`BusinessApplicationException` のみ）。

## スロー（B層）

```csharp
// 業務例外（リトライ可能）＝ロールバック後、リスローされず P層へ ErrorFlag で戻る
throw new BusinessApplicationException("MessageID_XXX", "エラーメッセージ", "エラー情報");

// システム例外（リトライ不可）＝ロールバック後、リスローされる
throw new BusinessSystemException("MessageID_YYY", "エラーメッセージ");
```

## 事前定義メッセージ定数（纏め者が用意。`opentouryo-base2-customize`）

```csharp
// Business.Exceptions 名前空間の定数クラス（string[]{ messageID, message }）
throw new BusinessApplicationException(
    MyBusinessApplicationExceptionMessage.SAMPLE_ERROR[0],
    MyBusinessApplicationExceptionMessage.SAMPLE_ERROR[1],
    "エラー情報");
```

外部ファイルのメッセージを使う場合は `GetMessage.GetMessageDescription("E0002")`（`opentouryo-message`）。

## P層での受け取り（業務例外は catch しない）

```csharp
// 業務例外：B層から正常系の戻り値として返る（catch しない！）
if (rv.ErrorFlag)
{
    // rv.ErrorMessageID / rv.ErrorMessage / rv.ErrorInfo
}

// システム例外・一般例外：リスローされ、共通エラー画面 or Application_Error で処理
```

> ★ 業務例外を `try/catch` で捕まえようとしない（飛んでこない）。詳細な処理フローは SKILL 本文。
> 例外→エラー画面の振替（`UOC_ABEND`）は親クラス2＝`opentouryo-base2-customize`。
