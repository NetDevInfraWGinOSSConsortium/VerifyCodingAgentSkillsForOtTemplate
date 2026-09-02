# 共有メモ：WS/3層依存サンプルの取り出しとビルド

`opentouryo-project-setup-core` で「WS/3層依存あり」のサンプル（`WebForms_Sample` / `WS_sample\WSClient_sample`
一式 ほか）を取り出すときに**共通で効く機構**。サンプル固有の癖は `<サンプル>.md`（同 `samples/` 配下）、
ここは WS まわりの共通部分をまとめる（サンプルが増えても共有できる）。

## なぜ `CS0246` が残るか／どう解消するか

WS/3層依存サンプルは、別サンプル **`WS_sample` の `WSIFType_sample` / `WSServer_sample`** を参照する。ソースでは
`WS_sample\Build\*.dll` への **HintPath（DLL 参照）**だが、`WS_sample\Build\` は **ZIP に含まれない生成物**なので
取り出し直後は `CS0246`。**解消は DLL を供給するのではなく、この2つを ProjectReference に切り替える**（下の原則）。

- `WSIFType_sample` … 受け渡し型（DTO。`TestParameterValue` / `TestReturnValue` 等）
- `WSServer_sample` … **B・D層**（WS サーバ）。`..\WSIFType_sample` を ProjectReference
- `WSClient_sample` … クライアント群（**P層**＝3層リッチクライアント。WinForms/WPF・net48）

## ★ 参照方式の使い分け（この節の中心・決め打ち）

3層CS は2種類の参照を明確に使い分ける：

- **フレームワーク `OpenTouryo.*`（親クラス＝バイナリ提供）→ DLL 参照**（ベンダ先 `OpenTouryoAssemblies\Build_net48\`）。
- **サンプル自身の `WSServer_sample`（B・D層）と `WSIFType_sample`（受け渡し型）→ ProjectReference**。
  理由：これらは導入プロジェクトで **P・B・D 層を並行開発する対象**（型と業務ロジックを触りながら P 層＝クライアントを作る）。
  DLL 参照だと編集のたびにビルド＆コピーが要り並行開発にならない。ProjectReference なら**同一ソリューションで編集が即伝播**する。
- → **`WS_sample\Build\` への DLL コピー＆その HintPath 参照は廃止**（旧 (A) の copy-to-Build 手順は不要）。

## ★ ProjectReference 化の共通注意（sln 追加・GUID 一致・全 proj 確認）

サンプル間参照を DLL→ProjectReference に切り替えるときは、どのサンプルでも次を守る（実測で踏む）：

- **★ (A) 化の前に「実使用」を確認する（目視検出で是正）。** csproj に WS 参照（`WSIFType_sample`/`WSServer_sample`）があっても、
  **`.cs`/`.cshtml` に WS 型（`using WSIFType_sample`・`TestParameterValue`/`TestReturnValue` 等）が無ければ、未使用の陳腐化参照**
  ＝**ProjectReference 化・sln 追加でなく、参照ごと削除する**（削除しても未使用なので `CS0246` は出ない）。
  実測：**`MVC_Sample` は WS 型 0 使用＝削除が正**（`samples/mvc.md`）／**WebForms は `sampleScreen_cc` が使うので (A)/(B) 判断が要る**。
  ＝**(A)/(B) は「参照の有無」でなく「実使用の有無」で決める**（機械的に全部 ProjectReference 化しない）。
- **アプリの `.sln` にも当該プロジェクトを追加する。** csproj を ProjectReference にしても、`.sln` に
  `WSIFType_sample`/`WSServer_sample` が無ければ **VS でビルド対象にならず `nuget restore <sln>` の対象からも漏れる**。
  `Project("{…}") = "<名>", "<相対パス>.csproj", "{GUID}"` 行＋`ProjectConfigurationPlatforms`（各プラットフォーム×2行）を足す。
  （WSClient の `_all.sln` は下記③に既述。**WebForms 等の単体 sln でも同じ**＝`samples/webforms.md`。）
  - **★ この追加は「静かに失敗」しうる＝改行を合わせ、行数で検算する。** sln の**改行コードは ref／ファイル／
    チェックアウト設定（`core.autocrlf`）で割れる**（実測でも同じ sln が ref により LF だったり CRLF だったりする＝
    「develop は CRLF」等と決め打ちしない）＝**編集するファイルの実際の改行を毎回確認して合わせる**。
    改行/アンカー不一致だと **`Project(...)` 行は入っても `ProjectConfigurationPlatforms` 行だけ無反応**になり、
    しかも **ProjectReference 経由でビルドは通る＝偽の成功**（VS で開いて初めて構成欠落が判明する）。
    → **追加後、`GlobalSection(ProjectConfigurationPlatforms)` 内の当該 GUID の行（＝構成数×2）を数えて実際に入ったか検算する**。
  - **★ 行の「右辺」に何を書くか＝ソリューション構成 ≠ プロジェクト構成**（これを間違えるとビルドが落ちる）。`_all.sln` のソリューション構成は **8 種**（`Debug\|.NET`/`Debug\|Any CPU`/`Debug\|Mixed Platforms`/`Debug\|x86` ×2）だが、`WSIFType_sample`/`WSServer_sample` の csproj が持つのは **`AnyCPU` だけ**。素直に恒等写像（`{GUID}.Debug\|Mixed Platforms.ActiveCfg = Debug\|Mixed Platforms`）を書くと **`BaseOutputPath/OutputPath プロパティが設定されていません`（`Platform='Mixed Platforms'`）でビルド失敗**。→ **同じ sln の既存プロジェクト（client/WCFService/ASPNETWebService）の行を雛形にして GUID だけ差し替える**（既存は 8 構成すべてを `Any CPU` へ写像している。**恒等写像にしない**）。源の 3proj sln に**最初の WS を追加する経路**でこれを踏む。
- **`<Project>` GUID を参照先と一致させる。** `<ProjectReference>` の `<Project>{GUID}</Project>` は
  **参照先 csproj の `<ProjectGuid>` と一致**させる（ずれると VS が再解決・警告）。
- **張替後、全プロジェクトで `ProjectReference` の実在を確認する。** 機械挿入の目印にする
  `Microsoft.CSharp.targets` の**インポート変数がプロジェクトで違う**（実測：client と `ASPNETWebService`＝`$(MSBuildBinPath)`／
  **`WCFService` だけ `$(MSBuildToolsPath)`**）。片方だけ見た置換だと**そのプロジェクトに ProjectReference が入らず、
  DLL 参照の削除だけ効いて `CS0246`**。→ 全 proj で `<ProjectReference>` を grep 確認する。
- **2つ目以降の WS 依存サンプルは取り出しを共有できる。** `WSIFType_sample`/`WSServer_sample` を先のサンプルで
  取り出し・ベンダ張替済みなら、**参照も不要でそのまま共有**（既に `..\..\OpenTouryoAssemblies\...`）＝**client と WS ホストだけ足せばよい**。

## (A) WS も一式取り出して 1 ソリューションで並行開発する

1. **取り出す** — `Samples\WS_sample\WSIFType_sample` と `WSServer_sample` を `WS_sample\` 直下の相対配置を保って取り出す
   （`WSServer` は `..\WSIFType_sample` を ProjectReference＝元からそう）。クライアント/ホストが起点なら合わせて取り出す。
2. **サンプル間は ProjectReference にする**（DLL 参照からの切替）：
   - **クライアント → `WSServer_sample`・`WSIFType_sample`**：旧 `..\..\Build\*.dll` の `<Reference>`+HintPath を**削除**し、
     各 `.csproj`（`..\..\WSServer_sample\WSServer_sample.csproj` 等）への `<ProjectReference>` にする。
   - **WS ホスト（ASPNETWebService/WCFService）→ 同2つ**：旧 `...\Samples\WS_sample\Build\*.dll` を**削除**し ProjectReference に。
   - `WSServer_sample → WSIFType_sample` は**源で ProjectReference（既定）**。**★ 2つを sln に追加するときは `WSIFType_sample` も
     確実に入れ（行数で検算）、`WSServer_sample`→`WSIFType_sample` の ProjectReference が生きていることを確認する**
     （WSIF が sln に無い／参照が切れると **`WSServer_sample` が `WSIFType_sample` を解決できずビルド不能**＝目視検出のエラー）。
3. **各プロジェクトの `OpenTouryo.*` は DLL 参照のままベンダ先へ張り替える**（`…\Frameworks\Infrastructure\Build\` →
   `…\OpenTouryoAssemblies\Build_net48\`。末尾フォルダ名も変わる。深さは配置に合わせる）。
4. **endpoint は触らない** — `Web.config`/`app.config` の endpoint はフレームワークの Transmission 設定（`opentouryo-transmission`）。

→ 取り出し・参照切替＝**セットアップ（④⑤）の範囲で完結**（transform 不要。`WS_sample\Build\` へのコピーは不要になった）。
参考スクリプトは `opentouryo-project-setup-build` の `examples.md`（`build-app.ps1`）。

## (B) WS 依存を切り離す

WS 依存が不要なら、後工程 **`opentouryo-project-transform`** で WS 参照を外し `CS0246` を潰す。
画面が WS 側の型を `using` しているケースの差し替え等は**サンプル固有**（`<サンプル>.md`（同 `samples/` 配下） / transform）。

## ランタイム注意：core のリモート WS は実用不可

.NET Core では **`BinaryFormatter` が廃止**され、リモート WS 呼び出し（`protocol="2"`〜`"5"`）は実質動かない
（インプロセスのみ）。**3層リッチクライアント（`WSClient_sample`）を実用するなら net48 側**を使う。
core 版 `Samples4NetCore\Legacy\WS_sample\WSClient_sample\` は起点として勧めない（`opentouryo-transmission` / §4.4）。

## 3層CS（WSClient）＝まず csproj を見て「3層WSクライアントか単独 P層か」判定する

**`WSClient_sample\` 配下でも variant ごとに依存構造が違う。名前（Win/WPF/Win2/WinCone）で決め打ちせず、必ず対象
variant の csproj を見て分岐する**（実測：Win/WPF/WinCone は WS 依存あり、Win2 は WS 依存なし）：

- **判定基準**：csproj に `WSServer_sample`/`WSIFType_sample` への参照があるか、`.cs` に WS 型（`TestParameterValue` /
  `TestReturnValue`）や `using WSIFType_sample;` があるか。加えて `<派生>_sample_all.sln` が同梱されているか。
- **あり → 3層WSクライアント**：下記の **① クライアント ② `WSServer_sample`/`WSIFType_sample`（B・D層・型） ③ WS ホスト
  `WS_sample\ServiceInterface`（源＝`Frameworks\Infrastructure\ServiceInterface`）** の3点を一式引き込む（クライアント単体では通信相手が居ない）。
- **なし → 単独の P層 UI デモ**（例：`WSClientWin2_sample`＝UserControl 親子・フォーム間の戻り値受け渡し等）：**WS ホスト
  引き込みも ProjectReference 化も不要。源同梱の単一 `.sln` のまま `OpenTouryo.*` の DLL 参照だけ張り替えて完結**。
  config も app.config に絶対 resource パスが無ければ張替不要（Win2 は該当キー無し・ローカル Content の XML は出力コピー）。
  ※ただし `Business.RichClient` は参照するので ③ の RichClient 追加ビルドは要る（**WS 軸と RichClient 軸は別**）。
  **★ 配置は例外にしない**：WS 非依存でも Win2 も他 variant と同じく **`WS_sample\WSClient_sample\WSClientWin2_sample\`** に置く
  （源の階層維持＝リポ直下に出さない）。WS 非依存なのは「参照の張替」の話で、置き場所は WSClient 派生と一律。よって
  `OpenTouryo.*` の HintPath は他 variant と同じ **3階層 `..\..\..\OpenTouryoAssemblies\Build_net48\`**（トップ直下＝`..\` にしない）。

**★ WSClient 4 variant の実測表（タグ 03-20・4種すべて実ビルド済み。依存形は3種＝名前で決め打ち不可の決定版）**：

| variant | client の WS 参照 | config 絶対パスキー | 構成 | 特記 |
| --- | --- | --- | --- | --- |
| `WSClientWin_sample` | WSServer＋WSIFType | 2（`SqlTextFilePath`＋`SpRp_RsaCerFilePath`） | 5proj | — |
| `WSClientWPF_sample` | WSServer＋WSIFType | 1（`SqlTextFilePath`） | 5proj | — |
| `WSClientWinCone_sample` | **WSIFType のみ**（WSServer は client 非参照） | 1（`SpRp_RsaCerFilePath`） | 5proj | **ClickOnce＝署名で MSB3482→下記** |
| `WSClientWin2_sample` | なし（WS 非依存） | 0 | 単一 sln | 単独 P層 UI デモ |

以下は「3層WSクライアント」（上表の 5proj 側＝Win/WPF/WinCone）の手順。②の取り出しとサンプル間 ProjectReference 化は
上の (A) 節、①③は下記。**client が参照する WS プロジェクトは variant による**（Win/WPF＝WSServer＋WSIFType、
WinCone＝WSIFType のみ）＝csproj を見て張り替える。

### ① クライアント（WSClientWin/WPF/WinCone）
1. **配置**：`WS_sample\` をリポ直下に置き（他サンプル同様 `Samples\` 段は落とす）、**`WS_sample\` の内部階層
   （`WSClient_sample\<派生>\`・`WSIFType_sample`・`WSServer_sample`）は保つ**（内部をフラット化しない＝サンプル間
   `ProjectReference` の相対パスを保つため。MAX_PATH は `long path` で回避）。**結果、client はリポ直下から3階層**。
   ★ **`Samples\` 段を落とすと `_all.sln` のホスト参照がずれる**（源は `Samples\` 前提）→ 下の ③「引き込み位置」で調整。
2. **⑤ 参照は2種類**：`OpenTouryo.*`（Business/Business.RichClient/Framework/Framework.RichClient/Public）＋`Newtonsoft.Json`
   は **DLL 参照**で 元 `..\..\..\..\Frameworks\Infrastructure\Build\` → **`..\..\..\OpenTouryoAssemblies\Build_net48\`**（3階層）。
   **client が参照する WS プロジェクト（上表）を ProjectReference**（旧 `..\..\Build\*.dll` の DLL 参照を削除し `.csproj` へ。(A)2）。
3. **⑥⑦ config は app.config に絶対 resource パスが在るキーだけを** `%OT_RESOURCE_ROOT%` 化する（**「2キー決め打ち」は誤り
   ＝variant で全部違う**。実測4/4：Win=2〔`SqlTextFilePath`＋`SpRp_RsaCerFilePath`〕・WPF=1〔`SqlTextFilePath`〕・
   WinCone=1〔`SpRp_RsaCerFilePath`〕・Win2=0。app.config を見て在るものだけ張り替える）。張替先は
   `SqlTextFilePath`→`%OT_RESOURCE_ROOT%\Sql`・`SpRp_RsaCerFilePath`→`%OT_RESOURCE_ROOT%\X509\SHA256RSA_Server.cer`。
   **`FxXML*`（XML 定義）は `EmbeddedResource`＝張替不要**。

### ③ WS ホスト `WS_sample\ServiceInterface`（源＝`Frameworks\Infrastructure\ServiceInterface`）も引き込む（実動の必須要素・見落とし注意）
**これが無いとクライアントは通信相手が居ない。** 源は `Frameworks\Infrastructure\ServiceInterface` だが、**WS 一式を `WS_sample\`
配下に集約**するため **`WS_sample\ServiceInterface\` に置く**（`WSClient_sample`/`WSIFType_sample`/`WSServer_sample` と兄弟）。
これはフレームワーク*ライブラリ*の改造ではない（WS ホスト アプリを配置・起動するだけ＝「Frameworks を取り込んで改造しない」に当たらない）。

> **⚠ 源を取り違えない**：**実体の WS ホスト源は `Frameworks\Infrastructure\ServiceInterface\{ASPNETWebService,WCFService}`**。
> **判定根拠は「中身が空か」ではなく「`_all.sln` が参照しているのはどちらか」**（`WSClientWin_sample_all.sln` がそのパスを参照＝裏取り）。
> ※ 現行 develop の `Samples\WS_sample\ASPNETWebService\` は**スタブではなく実体のある Web API サンプル**（17 ファイル。過去 ref では README だけだった）＝「空だから違う」で確認に行くと**空でないもの**を見て混乱する。「引き込むのはどちらか」だけが判断軸。
- **既定は `ASPNETWebService`**（クライアント app.config が `FxXMLTMProtocolDefinition=TMProtocolDefinition2.xml`＝Web API
  経路を選択。`WCFService` は代替＝`TMProtocolDefinition.xml`）。通常は ASPNETWebService を建てれば足りる。
- **引き込み位置**：`WS_sample\ServiceInterface\<host>\`（`<host>`＝`ASPNETWebService`/`WCFService`）。
- **★ `_all.sln` のホスト参照を新配置に張り替える**。源の `_all.sln` は client から `..\..\..\..\Frameworks\...\ServiceInterface\<host>\`
  を参照するので、**`..\..\ServiceInterface\<host>\<host>.csproj` に直す**（client＝`WS_sample\WSClient_sample\<派生>\` から
  `WS_sample\` へ up 2＝host と client は `WS_sample\` 内の兄弟）。
- **参照**：ホストの `OpenTouryo.*`（ASPNETWebService＝Framework/Public/Public.Security、WCFService＝Business/Framework/Public）は
  **DLL 参照**で `..\..\Build\` → ベンダ先 **`..\..\..\OpenTouryoAssemblies\Build_net48\`**（host は `WS_sample\ServiceInterface\<host>\`
  ＝リポ直下から3階層）。**`WSServer_sample`/`WSIFType_sample` は ProjectReference**：旧 `...\WS_sample\Build\*.dll` を削除し
  **`..\..\WSServer_sample\WSServer_sample.csproj`（同 `WSIFType_sample`）**（host は `WS_sample\` 内なので client と同じ `..\..\`）。
- **★ ホスト config も resource パスを張り替える**（実 WS 稼働に必要。build だけなら不要・run-verify で要る）：
  `ASPNETWebService`/`WCFService` の **`app.config`** に `C:\root\files\resource\...` が**6キー**（`FxXMLMSGDefinition` /
  `FxXMLTCDefinition` / `FxXMLTMInProcessDefinition` / `FxLog4NetConfFile` / `SqlTextFilePath` / `SpRp_RsaCerFilePath`）＝
  `%OT_RESOURCE_ROOT%\...` 化する。**ASPNETWebService は `Web.config` の `<appSettings file="app.config">` で app.config を
  実行時マージ**（`Web.config` だけ見ると絶対パスが無く見落とす）。**綴りは ref で割れる**（実測：ASPNETWebService=`Xml`／
  WCFService=`XML` の ref もあれば、両ホストとも `XML` の ref もある。実フォルダはいずれも `Xml`）＝**決め打ちせず実測して合わせる**（`resource-config.md` の綴り罠）。
- **復元**：`WCFService` は `PackageReference`＝`msbuild /t:Restore`。**`ASPNETWebService` は `packages.config`＝要注意**：
  `_all.sln` 一括 `nuget restore` はパッケージをソリューション ディレクトリ（client 側）に入れるが、`ASPNETWebService.csproj`
  の HintPath / `.targets` インポートは **csproj 相対 `packages\...`**（`Microsoft.Data.SqlClient.SNI.targets` 等）。
  → **`nuget restore <asp>\packages.config -PackagesDirectory <asp>\packages` で project 直下へ別途復元**する（実測。
  さもないと `.targets` 不明でビルド失敗）。
- **`.sln`＝3層一式の `_all.sln`。ただし源の `_all.sln` は全 variant で client＋WCFService＋ASPNETWebService の3プロジェクトのみ**
  （WSServer/WSIFType を含まず・client 側は `..\..\Build\*.dll` の DLL 参照）＝**ProjectReference 化には WSServer/WSIFType の
  2プロジェクト追加が必須**。さらに **`SolutionConfigurationPlatforms` が variant で違う**（実測：Win/WinCone＝8種
  〔Debug/Release × .NET/Any CPU/Mixed/x86〕、WPF＝4種〔Debug/Release × Any CPU/x86〕）。
  → **推奨手順：既に動く 5プロジェクトの `_all.sln`（repo 内の別 WS client）を雛形にコピーし、client の project 行
  （名前・パス・GUID）だけ差し替える**（共有4プロジェクト＝WCFService/ASPNETWebService/WSServer/WSIFType は GUID・パスを
  そのまま流用）。**最初の WS client で雛形が無いときだけ**、源の3プロジェクト `_all.sln` に WSServer/WSIFType を追加＋client の
  DLL 参照を ProjectReference 化する（追加行は既存インデント＝タブに合わせる）。※先の版で「`_all.sln` 削除・単一 sln」としたのは誤り。

### ★ ClickOnce variant（`WSClientWinCone_sample`）＝署名で `MSB3482` になる
WinCone は ClickOnce デプロイ版（"Cone"）で csproj に **`SignManifests=true`＋`ManifestCertificateThumbprint`＋`ManifestKeyFile`
（`.pfx`）＋`GenerateManifests=true`** を持つ。素の `msbuild /t:Build` は**マニフェスト署名**が走り、証明書がローカル ストアに
無いと **`MSB3482`（No certificates were found）でビルド失敗**（他4プロジェクトは署名前に成功）。
- **回避＝csproj の `<SignManifests>` を `false` にする**（到達点は「ビルド/オープン可能」＝ClickOnce publish は目的外）。
  **repo 内 csproj の変更のみ＝マシン全体の変更ではない**（`SETUP-CHANGES.md` 追記は不要）。
- **ClickOnce 固有ファイルも取り出す**：`<派生>_TemporaryKey.pfx`・`Properties\app.manifest`（`BaseApplicationManifest`）。
  漏れると別エラー（④ の Include 突き合わせで拾う）。

### 到達点
- **セットアップの到達点＝5プロジェクトが開けて 0 error でビルドできる**（クライアント〔P〕＋WSServer〔B・D〕＋WSIFType〔型〕
  ＋WS ホスト ASPNETWebService/WCFService。P・B・D を1ソリューションで並行開発できる状態）。
- **WS モード実動の確認は run-verify**：ASPNETWebService を IIS Express で起動 → クライアント exe から
  WS 越しに呼べること（`references/run-verify.md`）。ホスト未起動でもクライアントはインプロセス兼用で開ける。
- **★ セットアップ後に業務のサービス論理名を足したら、クライアントとサーバの両方の `TMInProcessDefinition.xml` に同じ `id` を登録し、リモート経路（`protocol="4"`/`"5"`）で1回叩く**——リモートは**サーバ側**（`%OT_RESOURCE_ROOT%\Xml\`）を引く。`protocol="1"`（インプロセス）はサーバ側を通らず3層を検証できない。編集後は**リサイクル必須**（`static` キャッシュ）。詳細＝`opentouryo-transmission`。
- **★ 既定プロトコルは develop で更新済み（実測 `TMProtocolDefinition2.xml`）**：生きているのは
  **`protocol="5"`（Web API＝`https://localhost:44349/WebAPIControllerForFx`）**と `protocol="4"`（net.tcp WCF）。
  **`protocol="2"`（ASMX＝`ServiceForFx.asmx`）と `3`（WCF-HTTP）はコメントアウト**され、`ServiceForFx.asmx` は
  ASPNETWebService に**存在しない**（GET 404）。＝旧「`protocol="2"` で確認」やファイル先頭コメント「2=WebService」は現行と合わない。
  非対話での WS ホスト稼働判定は `references/run-verify.md`（`GET /test`）。

## MAX_PATH(260)

深いリポ パスでは、相対配置を保つと `nuget restore` がパッケージ内部の深いパス
（`packages\...\analyzers\...\pt-BR\...`）で超過し失敗する。**取り出したプロジェクト**（`WebForms_Sample` 等）
**をリポ直下へフラット化**し、各 `.csproj` の相対 `HintPath`（`OpenTouryo.*` 等）を新配置に合わせて張り替える
（`long path` 有効化でも可）。
**※ WS 系（`WS_sample\` 一式）は例外＝フラット化しない**（上の①1。サンプル間 ProjectReference の相対パスを保つため
`long path` 側で回避）。**★ 余裕はほぼ無い（実測 256/260）**：`ASPNETWebService` の `packages.config` 復元後の最長パスは 256 文字で、リポ ルートが 47 文字程度のときで**あと 4 文字長いだけで復元が壊れる**＝**リポ ルートは短く選ぶ**（`LongPathsEnabled=0` でもルートが十分短ければ通る）。
