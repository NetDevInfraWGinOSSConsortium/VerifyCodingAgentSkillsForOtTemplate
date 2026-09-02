# 国際化（i18n）／地域化（L10n）（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。文字コードは `references/character-encoding.md`（別）。
出典：MS 技術情報「国際化対応項目」＋実ソース（OpenTouryo の i18n 部品）＋最新動向（末尾 Sources）。

## 対応項目（何を切り替えるか）

| 項目 | 中身 | .NET |
| --- | --- | --- |
| **文言**（UI・メッセージ） | 画面/ラベル/ボタン/エラー・確認/ツールチップ/ログ文言を**外部リソース化** | `.resx`＋`ResourceManager`／`CurrentUICulture` |
| **書式**（数値/日時/通貨） | 小数点・桁区切り、日時形式（ISO 8601 か各国）、通貨記号（`￥` 問題）、単位（メートル法/ヤード・ポンド） | `CurrentCulture`／`NumberFormat`・`DateTimeFormat`／`IFormatProvider` |
| **カレンダー** | 和暦/グレゴリオ/回教/韓国/台湾/タイ仏暦… | `CultureInfo.Calendar`＝`JapaneseCalendar`/`GregorianCalendar`… |
| **タイムゾーン・サマータイム** | **内部は UTC 保持**・表示時に時差/DST 調整 | `DateTime.UtcNow`/`TimeZoneInfo`/`IsDaylightSavingTime` |
| **和暦・元号** | 新元号対応（「昭和65年」を許すか） | net48 は config `Switch.System.Globalization.EnforceJapaneseEraYearRanges`（4.6+）／Core は別途 |
| **UI** | ラベル幅の変化・**双方向テキスト（RTL＝アラビア語等）** | Forms のリソース機能／レイアウト |
| **文字コード** | UTF-8/UTF-16 統一 | `references/character-encoding.md` |

## .NET の中核 API

- **`CultureInfo`**：`CurrentCulture`（**書式**用）／`CurrentUICulture`（**UI 表示言語**用）を**分けて扱う**。`Calendar`／`NumberFormat`／`DateTimeFormat`。
- 書式：`DateTime.ToString(format, CultureInfo)`／`DateTime.ParseExact(s, format, CultureInfo)`。和暦は `culture.DateTimeFormat.Calendar = new JapaneseCalendar()` → `ToString("ggyy年M月d日")`。
- `RegionInfo`（地域・通貨）。リソースは `.resx`（Visual Studio／管理画面／DB のどれで変更するか決める）。

## ★ 推奨設計：クライアント・サーバ型（どのロケールをどこで）

| 対象 | ロケール | 使う |
| --- | --- | --- |
| UI 表示リソース | **クライアント可変**（利用者が選ぶ） | `CurrentUICulture` |
| ログ メッセージ | **サーバ固定**（解析のため揃える） | `CurrentUICulture`（サーバ側に固定） |
| 書式処理（数値/日時） | クライアント可変 **または統一単位** | `CurrentCulture` |

**クライアント側ロケールは可変・サーバ側ロケールは固定**が基本。ログはサーバロケールに固定（`CurrentUICulture` を出力時に固定）、UI はクライアントで選ばせる。

## OpenTouryo の国際化対応部分

- **メッセージのカルチャ対応**：`FxExceptionMessageCulture`（config）＋**`MSGDefinition_<カルチャ>.xml`**（例 `MSGDefinition_ja-JP.xml`）／`GetMessage.GetMessageDescription(id, new CultureInfo("ja-JP"))`／フレームワーク例外は `.resx`（`opentouryo-message`）。
- **時刻**：**`GMTMaster`**（`Touryo.Infrastructure.Business.Util`・public）＝**ローカル時刻⇔UTC 変換**（内部 UTC 保持の実装に使う。`MyTimeZone` は internal）。
- **数値書式**：**`FormatConverter`**（`Touryo.Infrastructure.Public.Str`・public）＝丸め（`Round_Banker`／`Round_4sya5nyu`）・桁区切り（`AddFigure3`/`AddFigure4`/`AddFigureX`）・`Floor`/`Ceiling`・`ToUnixTime`。
- **文字コード検証**：`StringChecker`／`JIS2k4Checker`（`references/character-encoding.md`）。
- **画面文言の多言語化＝2方式**：既定は **`.resx`**（上記）／代替は **辞書テーブル方式**（画面名＋コントロール名→多言語。親クラス2 で Control を再帰走査して一括差し替え。**定義の可視性が良い**が **WebForms/WinForms のみ**＝MVC 不可）。→ `references/table-driven-control.md`。

## 設計時に決めること（要件チェック）

- **ラベル幅の変化**に耐える UI か（双方向＝RTL の要否）。
- リソースの**変更方法**（VS／管理画面／DB）と**バイナリ再配布の可否**。
- **OS ロケール依存**を許すか、**ユーザによる動的切り替え**の要否、**複数言語の同時混在**の要否。
- **時刻は UTC で保持**し表示時に変換（`GMTMaster`）。
- 和暦・元号の扱い（net48 は `EnforceJapaneseEraYearRanges`、Core は元号データ更新が別機構）。
- UI 表示＝クライアント／ログ＝サーバ固定／書式＝クライアント or 統一（上の C/S 設計）。

## Sources（最新動向）

- .NET Globalization / CultureInfo — https://learn.microsoft.com/en-us/dotnet/api/system.globalization.cultureinfo
- Globalization and localization in ASP.NET Core — https://learn.microsoft.com/en-us/aspnet/core/fundamentals/localization
- .NET time zones / TimeZoneInfo — https://learn.microsoft.com/en-us/dotnet/standard/datetime/time-zone-overview
