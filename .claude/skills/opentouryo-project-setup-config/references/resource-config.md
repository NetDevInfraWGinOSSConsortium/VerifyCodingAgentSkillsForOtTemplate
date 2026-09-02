# リソース移設と config パス張り替え（詳細）

`opentouryo-project-setup-config` ⑥ の詳細。Fx キー全般・`FxContainerization`（値まるごとを環境変数で上書きする別機構）・
`GetConfigParameter` は `opentouryo-config`。

## 原則（3つ）

1. **Resource を指す絶対パスは環境変数に張り替える。** 対象は .NET 設定ファイル（`*.config` / `appsettings.json`）と
   **LOG 系設定ファイル（`*.xml`）の中の絶対パス**。マシン固有パスを config に残さず可搬にする。
2. **`OT_RESOURCE_ROOT` が既設（別プロジェクトが使用中）なら奪い合わず番号を付ける**（`%OT_RESOURCE_ROOTn%`。例 `%OT_RESOURCE_ROOT1%`）。
   ユーザ環境変数はマシンで1つなので、別リポジトリの `resource\` を指したまま上書きすると相手が壊れる。
3. **一部の設定は正しくなくても（空値でも）アプリは起動する。** 「起動した＝設定が正しい」ではない。起動可否と設定の正しさは分けて確認する
   （例：ログ出力先が旧パスのままでも起動する＝下記）。

`OT_RESOURCE_ROOT`（またはその番号付き）＝リポジトリ直下の `resource\`。**ユーザ環境変数はマシン/ユーザ全体に残る＝`SETUP-CHANGES.md` に記録。**
**検証だけなら User 変数を変えず、プロセス限定上書き**（`$env:OT_RESOURCE_ROOT="<repo>\resource"` を起動コマンドで＝`run-verify.md`）で足り、記録も不要。

## パス系キー（張り替える対象）

| キー | 参照先 |
| --- | --- |
| `FxLog4NetConfFile` | `%OT_RESOURCE_ROOT%\Log\SampleLogConf.xml`（ログ定義ファイルの**場所**） |
| `FxXMLSPDefinition` / `FxXMLMSGDefinition` / `FxXMLSCDefinition` / `FxXMLTCDefinition` / `FxXMLTMProtocolDefinition` / `FxXMLTMInProcessDefinition` | `%OT_RESOURCE_ROOT%\Xml\*.xml` |
| `SqlTextFilePath` | `%OT_RESOURCE_ROOT%\Sql`（**※同梱型は例外＝下記**） |
| `SpRp_RsaCerFilePath` | `%OT_RESOURCE_ROOT%\X509\*.cer` |
| `TestFilePath` | `%OT_RESOURCE_ROOT%\Test`（実測で WebForms `app.config` に存在。**綴りは ref で割れる**＝実フォルダ `Test` に合わせる。現行 develop は `Test`） |

**★ ただしこの表を全部前提にしない。** キー集合はサンプル/ランタイムで違う（下記「キー集合・綴り・区切り」）＝**config に在るキーだけ**張り替える。

## 相対パスは不可

フレームワークは設定値を**フルパス前提**でファイル API に渡す。相対パス（`resource\...`）は実行プロセスの CWD 基準で解決され、
IIS Express / w3wp の CWD はアプリ フォルダでないため 500 になる。`ResourceLoader` が**パス解決直前に展開する `%環境変数%`** を使う。

## ★ 例外：デスクトップ（2CS・リッチクライアント）は相対・埋め込みが正＝「絶対パスのキーだけ」張り替える

「相対パスは不可」は **Web 前提**（IIS/w3wp の CWD がアプリ外だから）。**exe 起動のデスクトップ サンプルは意図的に相対＋埋め込み**で、
そのままが正。実測（`2CSClientWin_sample`）：

- `FxXMLMSGDefinition`/`FxXMLSPDefinition` は相対名 `MSGDefinition.xml`/`SPDefinition.xml`（csproj `CopyToOutputDirectory=Always` で
  exe の隣に配置＝`ResourceLoader` が `AppContext.BaseDirectory` 基準で解決）。
- `FxLog4NetConfFile` は**埋め込みリソース** `_2CSClientWin_sample.SampleLogConf2CS.xml`（名前空間依存＝アセンブリ名を変えると壊れる。
  改名規則は `opentouryo-project-setup`）。
- **絶対パスは `SqlTextFilePath`（`C:\root\files\resource\Sql`）の1キーだけ**。

→ **config を見て「絶対パス（`C:\root\…`）を持つキーだけ」張り替える。相対・埋め込みはアプリ同梱なので触らない**
（`%OT_RESOURCE_ROOT%` 化すると壊れる）。

## ★ 例外：SQL 同梱の自己完結型サンプル（`.\Dao`）は張り替えない

`SqlTextFilePath` が `.` 始まりの相対（net48 `.\Dao`／core `./Dao`）で、csproj が `Dao\*.sql/.xml` を `CopyToOutputDirectory`
しているなら**意図的な自己完結型＝そのまま残す**（`%OT_RESOURCE_ROOT%\Sql` に書き換えると SQL が無く逆に壊れる。例 `RerunnableBatch_sample`）。
コンソール exe を出力フォルダから実行する前提。

## ログ定義ファイルの中の出力先パス — 原則1だが起動は妨げない（原則3）

出力先を `%OT_RESOURCE_ROOT%\Log` へ揃えるのが原則1。ただし**張り替えなくても起動する**（ログが旧パスへ出る／無ければ黙って
出さないだけ＝セットアップ済みプロジェクトでも既定パスのまま稼働する）＝原則3。**`FxLog4NetConfFile`（ファイルの場所）は `%OT_RESOURCE_ROOT%` で
解決されるが、その中身は OpenTouryo が展開せずログライブラリへそのまま渡す**（log4net＝`XmlConfigurator`／NLog＝`XmlLoggingConfiguration`）。
＝**展開は各ログライブラリの書式**で行う。`LogLib`（log4net / NLog）の選択は `opentouryo-logging`。

**★ 絶対パスを持つログ定義は `SampleLogConf.xml` だけではない。** 実測（`resource\Log\`）で
`SampleLogConf.xml` / `SampleLogConfWebService.xml` / `SampleLogConf_N.xml`（NLog）/ `Examples of rolling of date+size.xml` /
`NLogConfigTemplate.xml` の**5ファイル**に `C:\root\files\resource\Log\...` がある
（`Log4NetConfigTemplate.xml` は `File` 値がプレースホルダ `（★ファイルパス）`で絶対パスを持たない＝対象外。
`SampleLogConf2CS.xml` は相対名 `ACCESS_2CS`＝デスクトップ同梱で対象外）。→ **`resource\Log\*.xml` を走査して該当を全件**張り替える
（1ファイル決め打ちにしない）。

- **log4net**：`%OT_RESOURCE_ROOT%` は効かない → `PatternString` の `%env{}`（`<param name="File">` を型付き `<file>` に置換）：
  ```xml
  <file type="log4net.Util.PatternString" value="%env{OT_RESOURCE_ROOT}\Log\ACCESS" />
  ```
- **NLog**：NLog の環境変数展開 **`${OT_RESOURCE_ROOT}`** を使う（as-built テンプレート `NLogConfigTemplate.xml` の書式）：
  ```xml
  <nlog ... internalLogFile="${OT_RESOURCE_ROOT}\Log\NLogInternalLog.log">
    <target xsi:type="File" name="ACCESS" fileName="${OT_RESOURCE_ROOT}\Log\ACCESS..." ... />
  ```
  テンプレート `resource\Log\NLogConfigTemplate.xml` の `（★ファイルパス）` を上の `${OT_RESOURCE_ROOT}\Log\...` に埋める。

## ★ キー集合・綴り・区切りはサンプル/ランタイムで割れる（決め打ち禁止）

**パス系キーの「集合」も「綴り」も「区切り」もサンプル/ランタイムで違う。上の表を全部前提にせず、config に在るキーだけ張り替える**（実測）：

| サンプル | config | パス系キー数 | 綴り | 区切り | 特記 |
| --- | --- | --- | --- | --- | --- |
| WebForms(net48) | `app.config` | 約11 | `Xml`/`Test`（ref 依存） | `\` | `TestFilePath` 有 |
| MVC(net48) | `app.config` | 5 | `Xml` | `\` | — |
| MVC(core) | `appsettings.json` | 7 | `Xml`（ref 依存） | **`/`** | `FxXMLTCDefinition`/`FxXMLTMInProcessDefinition` が増える |

- **★ 綴り（`Xml`/`Test`）は ref で割れる＝必ず実測して実フォルダに合わせる**（値を決め打ちしない。過去 ref には `XML`/`test` があり、現行 develop は `Xml`/`Test`＝実フォルダと一致し修正不要）。Windows は綴り無視だが **Linux で core を動かすなら実フォルダの綴りに合わせる**（WS ホストの綴りについて同 md が既にそう書いているのと同じ扱い）。
- **core（`appsettings.json`）固有**：
  - **値はスラッシュ区切り**（`C:/root/files/resource/XML/...`）。JSON なので `%OT_RESOURCE_ROOT%\\Xml\\...` と
    **バックスラッシュを2重エスケープ**して張り替える（`/` のままでも Windows では通るが、repo 内 net48 側と表記が割れる）。
  - **`//` コメント入り（JSONC）**。ASP.NET Core の JSON プロバイダはコメントを許容する＝**そのまま残す**
    （厳密な JSON パーサで整形し直すと壊れる）。
- **core は net48 MVC より2キー多い**（`FxXMLTCDefinition`/`FxXMLTMInProcessDefinition`）＝同名サンプルでもランタイムで割れる。
  **前ラウンドで core の ⑥ が見落とされた実績あり**（傍証：`appsettings.json` が `C:/root/...` のままコミットされていた）。
- **net48 Web Forms は config 二段**：パス系キーは `<appSettings file="app.config"/>` の **`app.config` 側**、
  接続文字列は `Web.config` 直下（`samples/webforms.md`）。core は `appsettings.json` に集約。
