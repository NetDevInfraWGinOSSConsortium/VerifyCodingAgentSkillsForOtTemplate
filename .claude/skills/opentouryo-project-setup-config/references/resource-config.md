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
| `SpRp_RsaCerFilePath` / `SpRp_RsaPfxFilePath` | `%OT_RESOURCE_ROOT%\X509\*.cer` / `*.pfx` |
| `TestFilePath` | `%OT_RESOURCE_ROOT%\Test`（実測で WebForms `app.config` に存在。**綴りは ref で割れる**＝実フォルダ `Test` に合わせる。現行 develop は `Test`） |

**★ ただしこの表を全部前提にしない。** キー集合はサンプル/ランタイムで違い、ref が進むとキーが増える（実測：develop の core MVC で
`SpRp_RsaPfxFilePath` が増えた）＝**表はキーの例。張り替える対象はキー名ではなく値で決める**：

1. config の**値に絶対パス `C:\root\` / `C:/root/` を持つキーを全部**張り替える（`C:\root\files\resource\` の後ろはそのまま残す）。
   表に無いキーも張り替える。相対・埋め込み・`.\Dao` は絶対パスでないので、この決め方で自然に対象外になる（下記の例外）。
2. 張り替えた後、config に `C:\root` / `C:/root` が**値として残っていないこと**を検索で確かめる（コメント中は下記 core の項のとおり直す）。
3. **表と実物が違ったら**（表に無いキー・数の違い・参照先のフォルダが無い）、張り替えは実物に合わせて行い、違いを**問題点として報告**する
   （スキルの表を直す材料。参照先の `resource\` のフォルダやファイルが無いなら、張り替えずに止めて人に聞く）。

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
- **NLog**：`fileName` は NLog の環境変数の書式 **`${environment:OT_RESOURCE_ROOT}`**（`${名前}` は NLog 自身の変数を指し、環境変数は展開されない）。
  `internalLogFile` は `%OT_RESOURCE_ROOT%`：
  ```xml
  <nlog ... internalLogFile="%OT_RESOURCE_ROOT%\Log\NLogInternalLog.log">
    <target xsi:type="File" name="ACCESS" fileName="${environment:OT_RESOURCE_ROOT}\Log\ACCESS..." ... />
  ```
  実物のテンプレート `NLogConfigTemplate.xml` は `internalLogFile` が絶対パス `C:\root\...`、`fileName` が `（★ファイルパス）`（環境変数は使っていない）。
  **未実測**（NLog を使うサンプルで実行して確かめていない）＝NLog を使うなら、張り替えた後にログが `resource\Log` に出ることを確かめる。

## ★ キー集合・綴り・区切りはサンプル/ランタイムで割れる（決め打ち禁止）

**パス系キーの「集合」も「綴り」も「区切り」もサンプル/ランタイムで違う。上の表を全部前提にせず、config に在るキーだけ張り替える**（実測）：

| サンプル | config | パス系キー数 | 綴り | 区切り | 特記 |
| --- | --- | --- | --- | --- | --- |
| WebForms(net48) | `app.config` | 12（develop・2026-11） | `Xml`/`Test`（ref 依存） | `\` | `TestFilePath` 有 |
| MVC(net48) | `app.config` | 6（develop・2026-11） | `Xml` | `\` | — |
| MVC(core) | `appsettings.json` | 8（develop・2026-11） | `Xml`（ref 依存） | **`/`** | `FxXMLTCDefinition`/`FxXMLTMInProcessDefinition`/`SpRp_RsaPfxFilePath` が増える |

キー数は実測した時点の値（ref が進むと変わる）。張り替えの対象は上の「値で決める」で決め、この数で決めない。

- **★ 綴り（`Xml`/`Test`）は ref で割れる＝必ず実測して実フォルダに合わせる**（値を決め打ちしない。過去 ref には `XML`/`test` があり、現行 develop は `Xml`/`Test`＝実フォルダと一致し修正不要）。Windows は綴り無視だが **Linux で core を動かすなら実フォルダの綴りに合わせる**（WS ホストの綴りについて同 md が既にそう書いているのと同じ扱い）。
- **core（`appsettings.json`）固有**：
  - **値はスラッシュ区切り**（`C:/root/files/resource/XML/...`）。JSON なので `%OT_RESOURCE_ROOT%\\Xml\\...` と
    **バックスラッシュを2重エスケープ**して張り替える（`/` のままでも Windows では通るが、repo 内 net48 側と表記が割れる）。
  - **`//` コメント入り（JSONC）**。ASP.NET Core の JSON プロバイダはコメントを許容する＝**そのまま残す**。
    コメント中の `C:/root/...`（「下の C:/root/... は…」）は動作に関係しないが、張り替えた後は実態と食い違うので、`%OT_RESOURCE_ROOT%`（番号付きならその名前）に合わせて直す
    （厳密な JSON パーサで整形し直すと壊れる）。
- **core は net48 MVC より2キー多い**（`FxXMLTCDefinition`/`FxXMLTMInProcessDefinition`）＝同名サンプルでもランタイムで割れる。
  **前ラウンドで core の ⑥ が見落とされた実績あり**（傍証：`appsettings.json` が `C:/root/...` のままコミットされていた）。
- **net48 Web Forms は config 二段**：パス系キーは `<appSettings file="app.config"/>` の **`app.config` 側**、
  接続文字列は `Web.config` 直下（`samples/webforms.md`）。core は `appsettings.json` に集約。
