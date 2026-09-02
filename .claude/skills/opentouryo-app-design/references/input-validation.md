# 入力値のチェック（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。**検証部品は `opentouryo-common-parts`／エラーの返し方は `opentouryo-exception`**。
出典：OpenTouryo「入力値のチェック」＋実ソース（`Public/Str/StringChecker.cs`・`FormatChecker.cs`）。

## チェックの3種類

| 種類 | 内容 | どの層 |
| --- | --- | --- |
| **単項目チェック** | 必須／型（数値・日付）／桁数・範囲／**文字種**／**正規表現**／**禁則文字** | P層（画面）＋サーバ側でも |
| **関連チェック** | 項目間の相関、**DB 側の状態**を使うチェック | **B層（サーバ）** |
| 業務チェック | 業務ルール（在庫・限度額 等） | B層 |

## ★ サーバ側の検証は必須（クライアントだけで済ませない）

- **電文（リクエスト）は直接叩けるため、クライアント側チェックだけでは守れない。** 関連・業務チェックは**サーバ側（P/B層）で必ず**行う（2層C/S を除く）。
- 近年は **P・B層（サーバ）に検証を集約する傾向**（JS のチェック部品は仕様がまちまちで表示整合が難しい）。クライアント側は UX 補助として任意。

## OpenTouryo の検証部品（`opentouryo-common-parts`）

- **`StringChecker`**（`Public/Str`・static）：`IsNumeric`／`IsNumbers`／`IsHankaku`／`IsZenkaku`／`IsHiragana`／`IsKatakana`／`IsKanji`／**`IsInCodePage`・`IsShift_Jis`**（文字集合＝`references/character-encoding.md`）／**`Match`（正規表現）**。
- **`FormatChecker`**（`Public/Str`・static）：**日本向け書式**＝`IsJpZipCode`（郵便番号）／`IsJpTelephoneNumber`／`IsJpFixedLinePhoneNumber`／`IsJpCellularPhoneNumber` 等。
- 型は `DateTime.TryParse`（日付）・`decimal.TryParse` 等。**ASP.NET Validator コントロールは制限が多く使用を絞る傾向**。
- **WinForms は `Control.Validating`** で単項目チェック（**データアクセスを伴わない単項目は標準イベントでよい**＝`opentouryo-layer-p-winforms-event`）。

## ★ 単項目チェックの標準化＝カスタムコントロール ＋ Control 再帰走査

- **バリデーション機能付きカスタムコントロール**（`WebCustomTextBox`／`WinCustomTextBox`＝`ICheck` 実装。`Frameworks/Infrastructure/CustomControl`）を使う。
- **チェック種別の指定は2通り**：①カスタムコントロールの **`CheckType`**（`Required`＝必須／`IsNumeric`＝数値／禁則文字 等）を**宣言的**にデザインタイム指定／②**単項目チェックテーブル**（画面名・コントロール名・チェック種別を持たせ**テーブル駆動**。多言語化/権限・状態/閉塞と同じ発想＝`references/table-driven-control.md`）。内部は `StringChecker`／`CmnCheckFunction` を呼ぶ。
- **一括実行＝画面コードクラスのイベントハンドラ**（サブミット系の `UOC_btnXXX_Click` 等）**で Control ツリーを再帰走査**し、`ICheck` を実装するコントロールの検証を呼ぶ：`if (ctrl.HasControls()/HasChildren) { foreach (child in ctrl.Controls) 再帰 }`。
- **★ 実装するのは開発者（画面コードクラス）。** 多言語化/権限・状態/閉塞（`references/table-driven-control.md`）が**親クラス2（纏め者・全画面で自動）**なのと**場所・実装者・タイミングが違う**（**再帰走査の手法だけ共通**。単項目チェックは画面ごと・サブミット時）。WebForms/WinForms 向き。
- ※ カスタムコントロール自体は CustCtrl 領域（本 repo 未整備）。サンプル `testWCTextBox.aspx`。

## エラーの返し方・セキュリティ

- **入力チェックエラーは業務例外**（`BusinessApplicationException`。**やり直せるのでシステム例外にしない**）。結果は `ErrorFlag`／`Information`（`opentouryo-exception`）。
- サーバ側検証は**セキュリティの一環**：ユーザ入力を **`SetUserParameter`（`%名前%`／`<VAL>`）に渡さない**（SQL インジェクション＝`opentouryo-query-definition`／`opentouryo-dao-custom`）。表示・ログ時は HTML エンコード（XSS）。

## 設計時に決めること（チェック）

- 単項目（P層）／関連・業務（B層）の**どこで何を**チェックするか。**サーバ側検証は必須**。
- 使う部品（`StringChecker`／`FormatChecker`／正規表現／`TryParse`）。
- エラーは**業務例外**で返す（メッセージは `opentouryo-message`）。
- ユーザ入力は**パラメタ（`@`）で渡す**・ユーザパラメタに渡さない（インジェクション対策）。
