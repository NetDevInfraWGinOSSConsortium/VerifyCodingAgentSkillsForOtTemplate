---
name: opentouryo-common-parts
description: "OpenTouryo が Public 名前空間に用意している共通部品（ユーティリティ）を用途から探す。自作する前にここを見る。文字列のチェック（StringChecker / FormatChecker）と変換（StringConverter / FormatConverter）、エンコード・サニタイズ（CustomEncode の HtmlEncode / UrlEncode / Base64 / 16進）、文字コード（JIS2k4Checker / CheckCharCode）、暗号・ハッシュ・署名・JWT（GetHash / GetPassword / SymmetricCryptography / DigitalSign / JWS / JWE）、圧縮とリソース（Zipper / ResourceLoader / EmbeddedResourceLoader）、DTO 変換（DataToPoco / PocoToPoco / DataToDictionary）、診断（StackFrameOperator）、配列（ArrayOperator）、レイトバインド（Latebind）などを扱う。Security は独立アセンブリ、Zipper / UnZipper / BinarySerialize / Win32 は net48 専用（net10.0 では未ビルド）といったランタイム差も示す。共通部品 / ユーティリティ / 部品を探す / 車輪の再発明を避ける / 文字列チェック / エンコード / ハッシュ / 暗号 / Zip / サニタイズ を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 共通部品（ユーティリティ）を用途から探す

## このスキルの使いどき

**ユーティリティ的な処理を自作する前に、OpenTouryo に既存部品がないか探す。**
文字列チェック・エンコード・ハッシュ・圧縮などは、たいてい `Public` 名前空間に揃っている。

- **セキュリティに関わる処理は特に自作しない。** エンコード（XSS 対策）・ハッシュ・暗号は
  フレームワークの部品を使う（下記）
- **メソッドの正確なシグネチャは、ソース（＝ API リファレンスは Doxygen 生成なのでソースと同じ）
  を見る。** ここは「どこに何があるか」の地図

名前空間は `Touryo.Infrastructure.Public.<カテゴリ>`。

## 文字列：チェック / 変換

| クラス（`...Public.Str`） | 用途 | 代表メソッド |
| --- | --- | --- |
| `StringChecker` | 種別チェック | `IsNumeric` / `IsHankaku` / `IsZenkaku` / `IsKatakana` / `IsKanji` / `IsShift_Jis` / `Match`（正規表現） |
| `FormatChecker` | 書式チェック（日本向け） | `IsJpZipCode` / `IsJpTelephoneNumber` / `IsJpCellularPhoneNumber` |
| `StringConverter` | 変換 | `ToZenkaku` / `ToHankaku` / `ToHiragana` / `ToKatakana` |
| `FormatConverter` | 書式変換 | `Round_Banker`（丸め）、西暦・和暦、桁区切り |
| `JIS2k4Checker` | JIS2004 追加文字・サロゲートペア | チェック / 削除 |
| `CheckCharCode` | 文字コードのチェック | |

**入力値の検証は自作正規表現より先にこれを探す。** 郵便番号・電話番号・全半角・かな・漢字は揃っている。

## エンコード / サニタイズ（`CustomEncode`）

`Touryo.Infrastructure.Public.Str.CustomEncode`。**XSS 対策の HTML エンコードは自作しない。**

| メソッド | 用途 |
| --- | --- |
| `HtmlEncode` / `HtmlDecode` | **HTML エンコード（XSS 対策）** |
| `UrlEncode` / `UrlDecode` | URL エンコード（`opentouryo-oauth2-client` でも使用） |
| `ToBase64String` / `FromBase64String` | Base64 |
| `ToBase64UrlString` / `FromBase64UrlString` | Base64URL |
| `ToHexString` / `FormHexString` | 16進 |
| `StringToByte` / `ByteToString` | コードページ指定のバイト⇔文字列 |

## 暗号・ハッシュ・署名（`...Public.Security`）

**暗号処理を自作しない。** 豊富に揃っている。詳細はソース参照。

**`Public.Security` は独立したアセンブリ**（`Public.Security` プロジェクト）。参照設定が要る。
**net48 / net10.0 の両対応**（core では `IdentityImpersonation` と CNG ベースの ECDH 鍵交換
だけ未ビルド）。

| クラス | 用途 |
| --- | --- |
| `GetHash` | ハッシュ（`GetHashString` / `GetHashBytes`、`EnumHashAlgorithm`、ストレッチ回数指定可） |
| `GetKeyedHash` / `MsgAuthCode` | キー付きハッシュ・MAC |
| `Pwd.GetPassword` | パスワード・乱数生成（`Base64Secret` / `Base64UrlSecret` / `Generate`） |
| `Pwd.GetPasswordHashV2` | パスワードハッシュ（**`V1` は非推奨**。`AGENTS.md` 参照） |
| `SymmetricCryptography` / `ASymmetricCryptography` | 共通鍵 / 公開鍵暗号 |
| `DigitalSign` ほか | 電子署名（X509 / XML / ECDSA など） |
| `Jwt*`（`JwtJWS_*` / `JwtJWE_*`） | JWT（JWS 署名 / JWE 暗号）。OIDC の `id_token` 検証などで使う |

パスワードの乱数は `GetPassword.Base64UrlSecret(n)` を使う（`opentouryo-oauth2-client` の
`state` / `nonce` 生成でも使用）。

## ファイル / IO（`...Public.IO`）

| クラス | 用途 | ランタイム |
| --- | --- | --- |
| `Zipper` / `UnZipper` | ZIP 圧縮・展開 | **net48 のみ**（net10.0 では未ビルド） |
| `BinarySerialize` | バイナリ シリアライズ | **net48 のみ**（net10.0 では未ビルド） |
| `DeflateCompression` | Deflate 圧縮 | net48 / net10.0 |
| `ResourceLoader` / `EmbeddedResourceLoader` | ファイル / 埋め込みリソースの読み込み | net48 / net10.0 |
| `ExponentialBackoff` | 指数バックオフ（リトライ） | net48 / net10.0 |

**`Zipper` / `UnZipper` / `BinarySerialize` は `net10.0`（core）のプロジェクトでビルド対象から
除外されている。** core では使えないので、圧縮は `DeflateCompression` か標準ライブラリを使う。
`Win32` / `WinProc` 名前空間（Windows API ラッパ）も net48 専用。

## DTO / データ変換（`...Public.Dto`）

| クラス | 用途 |
| --- | --- |
| `DataToPoco` / `PocoToPoco` | `DataTable` ⇔ POCO、POCO ⇔ POCO の詰め替え |
| `DataToDictionary` | `DataTable` → `Dictionary` |
| **`DTTables` / `DTTable`** | **`DataSet`/`DataTable` ⇄ JSON 文字列**の相互変換（`DTTables.FromDataSet`/`ToDataSet`・`DTTable.FromDataTable`/`ToDataTable`・`DTTables.DTTablesToJson`/`JsonToDTTables`〔`SaveJson`/`LoadJson` は `TextWriter`/`Reader` 版〕）。**`RowState`〔Added/Modified/Deleted〕を往復で保持**＝WebAPI 転送や Core の Session 格納に使う。**`Original`〔変更前値〕は既定 非保持・`FromDataTable(dt, keepOriginal:true)` で保持可**、列属性〔`AutoIncrement`/`PrimaryKey` 等〕は非保持。詳細＝`opentouryo-batch-update` |

## その他

| カテゴリ | クラス | 用途 |
| --- | --- | --- |
| 診断 | `StackFrameOperator`（`...Diagnostics`） | 現在のメソッド名・プロパティ名の取得。`ObjectInspector` |
| 配列 | `ArrayOperator`（`...Util`） | 配列の結合・コピー等（**旧 `PubCmnFunction` の代替**） |
| 文字列変数 | `StringVariableOperator`（`...Str`） | プロパティ文字列の展開等（同上・代替） |
| 性能 | `PerformanceRecorder`（`...Util`） | 性能測定 |
| 乱数 | `RandomValueGenerator`（`...Util`） | 乱数生成 |
| レイトバインド | `Latebind`（`...Reflection`） | 動的メソッド呼び出し（B層の自動振り分けが使用） |
| 高速リフレクション | `...FastReflection` | コンパイル式によるアクセサ・生成 |

## 専用スキルがある領域

以下は共通部品だが、扱う専用スキルがある。**そちらを見る。**

| 領域 | クラス | スキル |
| --- | --- | --- |
| データアクセス制御（Dam） | `...Public.Db`（`DamSqlSvr` / `DamManagedOdp` ほか）、`DbEnum` | `opentouryo-p-call-business` / `opentouryo-layer-d` |
| ログ | `LogIF` / `CustomEventLog` / `SecurityEventLog`（`...Public.Log`） | `opentouryo-logging` |
| 設定取得 | `GetConfigParameter`（`...Public.Util`） | `opentouryo-config` |
| バッチ SQL | `SQLUtility`（`...Public.Db`） | `opentouryo-dao-custom` |

## やってはいけないこと

- **既存部品を探さずにユーティリティを自作する** — 文字列チェック・エンコード・圧縮・ハッシュは
  たいてい `Public` にある。まず探す
- **HTML エンコード・暗号・ハッシュを自前実装する** — セキュリティに関わる。`CustomEncode` /
  `Public.Security` を使う
- **`PubCmnFunction` を使う** — 非推奨。`StringVariableOperator` / `StackFrameOperator` /
  `ArrayOperator` に移動している（`AGENTS.md` の非推奨一覧）
- **`GetPasswordHashV1` を使う** — 非推奨。`GetPasswordHashV2`
- **メソッドのシグネチャを推測で書く** — API リファレンス（＝ソース）で確認する
- **`net10.0` で `Zipper` / `UnZipper` / `BinarySerialize` / `Win32` を使う** — core では
  ビルド対象外。net48 専用。core では別手段を使う
