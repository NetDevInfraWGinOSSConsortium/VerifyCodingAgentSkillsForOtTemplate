# ログ出力 コードスニペット（コピー元）

出典：UserGuide 纏め者編 §1.3／共通編、`Public/Log/LogIF.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## ログ出力 API（loggerName ＋ message）

```csharp
using Touryo.Infrastructure.Public.Log;

LogIF.DebugLog("ロガー名", "メッセージ");
LogIF.InfoLog("ロガー名", "メッセージ");
LogIF.WarnLog("ロガー名", "メッセージ");
LogIF.ErrorLog("ロガー名", "メッセージ");
LogIF.FatalLog("ロガー名", "メッセージ");
```

> ★ ロガー名は**定数がなく文字列直書き**。タイポするとコンパイル・実行時チェックを通らずログが消える。
> プロジェクトでロガー名の定数を用意すると安全。

## 標準ロガー（サンプルの SampleLogConf.xml）

| ロガー | 用途 | 書式（既定） |
| --- | --- | --- |
| `ACCESS` | アクセストレース | カンマ区切り |
| `SQLTRACE` | SQL トレース | カンマ区切り |
| `OPERATION` | オペレーション（業務操作） | 運用ルール依存（`opentouryo-project-policy`） |
| `SERVICE-IF` | サービスインターフェイス | — |

`ACCESS`/`SQLTRACE` の書式は親クラス2 の `LogIF` 呼び出しに依存（`opentouryo-project-policy`／`-base2-customize`）。

## ログ ライブラリの選択（log4net / NLog）

`LogIF` の実装は config `LogLib` で切り替わる（実ソース `LogIF.cs`＝`Log_log4net`/`Log_nlog`）：
**未設定/`log4net`＝log4net、`nlog`＝NLog**（大小無視）。`LogIF` の API は共通。
**★ 設定ファイルのパスは log4net/NLog とも同じキー `FxLog4NetConfFile`** で指す（NLog も実ソースでこのキーを読む）。
違うのは**ファイルの中身（フォーマット）**：log4net 形式か NLog 形式か。雛形が `root\files\resource\Log` にある：
**`Log4NetConfigTemplate.xml`（log4net）／`NLogConfigTemplate.xml`（NLog）**。`SampleLogConf.xml` はサンプルの実 log4net 設定。
下のアペンダ例は **log4net 形式**。

## log4net アペンダ（ローリング・複数プロセス・即時フラッシュ）※log4net 選択時

```xml
<!-- サイズローリング＋バックアップ数固定 -->
<appender name="XXX" type="log4net.Appender.RollingFileAppender">
  <param name="File" value="（パス）" />
  <param name="RollingStyle" value="size" />
  <param name="MaximumFileSize" value="10MB" />
  <param name="MaxSizeRollBackups" value="2" />
  <param name="AppendToFile" value="true" />
  <encoding value="utf-8" />
  <layout type="log4net.Layout.PatternLayout">
    <param name="ConversionPattern" value="[%date{yyyy/MM/dd HH:mm:ss,fff}],[%-5level],[%thread],%message%newline" />
  </layout>
</appender>
```

- **複数プロセスから1ファイルへ**：appender の子に `<lockingModel type="log4net.Appender.FileAppender+MinimalLock" />`（性能は劣化）。
- **バッファリング**：`<ImmediateFlush value="False" />`（Disk I/O 軽減。既定 True＝即時・クラッシュ時も全出力）。
- config パス（key）：`<add key="FxLog4NetConfFile" value="（パス）\（log設定）.xml"/>`（共通キー・雛形・読み替えは上の「ログ ライブラリの選択」節）。
