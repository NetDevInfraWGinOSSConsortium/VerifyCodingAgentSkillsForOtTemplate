# 文字コード・エンコーディング・キャラクタセット（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。
出典：OpenTouryo「文字コード、エンコーディング、キャラクタセット」＋実ソース（`Public/Str/StringChecker.cs`・`JIS2k4Checker.cs`）＋最新動向（末尾 Sources）。

## 基本方針

- .NET／Java の文字列は**内部 UTF-16**、外部は既定 **UTF-8**。**現代は入口から出口まで UTF-8/Unicode で統一**が基本。
- 異なる文字コード間の連携時だけ変換が要る。**可逆変換できるかを検証**する（外字・機種依存文字は化ける／欠落する）。

## OpenTouryo の文字チェック部品（`Touryo.Infrastructure.Public.Str`）

- **`StringChecker`**（static）＝文字種・コードページの検証：
  - 文字種：`IsNumbers`（`_Hankaku`/`_Zenkaku`）／`IsHankaku`／`IsZenkaku`／`IsAlphabet(...)`／`IsHiragana`／`IsKatakana(...)`／`IsKanji`。
  - **`IsInCodePage(input, codePageNum)`＝指定コードページで可逆か**（＝その文字集合に収まるか）。**`IsShift_Jis(input)`**（`_Zenkaku`/`_Hankaku` 有）＝SJIS 可逆チェック。→ DB・外部系が SJIS／特定コードページのとき、**格納前に入力を検証**して外字・機種依存文字を弾く。
  - `Match(input, pattern[, options])`＝正規表現。
- **`JIS2k4Checker`**（JIS2004・サロゲートペア＝4バイト文字/絵文字）：
  - `CheckSurrogatesPairChar(input[, out index])`＝**サロゲートペアを含むか検出**／`DeleteSurrogatesPairChar(input[, replaceChar/replaceString])`＝**除去・置換**／`GetStringInfo(input, out s_length, out si_length, out byte_length)`＝サロゲート考慮の文字数・バイト数（.NET `System.Globalization.StringInfo` を内包）。
  - **絵文字・第3/第4水準漢字**はサロゲートペア。SJIS や不適切な照合順序では**化ける／切れる**ので、要件に応じて検出→拒否/置換。

## JIS の水準（対応時の注意）

- **JIS X 0208**（非漢字・第1/第2水準）／**JIS X 0212**（補助漢字）／**JIS X 0213・JIS2004**（第3/第4水準＝一部サロゲートペア）。
- **扱う水準を決めて DB・画面・帳票・外部連携で揃える**（片方が対応していないと化け・欠落・例外になる）。

## Web/HTML の文字化け

- HTML を Shift-JIS 指定にすると、SJIS で表現不可な文字は**数値文字参照**に自動変換される（例 `鱓` → `&#40019;`）。
- **現代は `<meta charset="utf-8">` ＋レスポンス UTF-8** で回避（キャッシュ制御は `references/cache-control.md`）。

## DB・ファイル・コード側（既存スキルへ）

- **SQL 定義ファイルのエンコード＝`FxSqlEncoding`**（`opentouryo-config`）。
- **新規／書き直したソースとビュー（`.cshtml`/`.aspx`/`.master`）は UTF-8 BOM**（MS ツールの既定コードページ誤読対策。実害が確認済みなのは
  net48 の実行時コンパイル ビュー＝`opentouryo-comment-convention`／配布 `AGENTS.md`「MS 系開発ツールの落とし穴」）。
- **多言語メッセージ**＝`opentouryo-message`（`.resx` / `MSGDefinition`）。
- **DB の文字コード／照合順序**：SQL Server は `nvarchar`（Unicode）、MySQL は **`utf8mb4`**（絵文字＝4バイト対応。`utf8`〔3バイト〕は不可）。列型・照合順序を Unicode で統一。

## 設計時に決めること（チェック）

- 全体を **UTF-8/Unicode で統一**（内部 UTF-16・外部 UTF-8）。
- **入力の文字集合を検証するか**（SJIS／コードページ互換が要るなら `StringChecker.IsInCodePage`／`IsShift_Jis`）。
- **サロゲートペア（絵文字・第3/4水準）を許可するか**（許可なら DB は `nvarchar`／`utf8mb4`。不可なら `JIS2k4Checker` で検出→拒否/置換）。
- 外部連携で異なる文字コードが要るなら**可逆変換を検証**する。

## Sources（最新動向）

- .NET character encoding — https://learn.microsoft.com/en-us/dotnet/standard/base-types/character-encoding-introduction
- MySQL `utf8mb4`（絵文字・4バイト）— https://dev.mysql.com/doc/refman/8.0/en/charset-unicode-utf8mb4.html
