# 実行確認（IIS Express での WebForms スモークテスト）

`opentouryo-project-setup-config` ⑦「ビルドが通り、実行できることを確認する」の具体手順（net48 Web Forms）。
ビルド成功＝動く、ではない。フレームワーク初期化は `%OT_RESOURCE_ROOT%` から XML 定義・log4net を読むので、
**実行して初めて resource/config 張り替え（⑥）の成否が分かる**。

## 手順

1. **プレーン HTTP ポートで起動して SSL 証明書バインドを回避する。** サンプルの既定は
   `IISUrl=https://localhost:44371/`（SSL）で、証明書が無いと詰まる。`http` ポートを指定して起動する：

   ```
   iisexpress.exe /path:"<repo>\WebForms_Sample\WebForms_Sample" /port:8080 /clr:v4.0
   ```

   **`/path` は Web ルート＝`Web.config` があるフォルダを指す**（実測で 1 階層ずれやすい）。WebForms サンプルは
   `.sln` が外側 `WebForms_Sample\`、**`Web.config` は内側 `WebForms_Sample\WebForms_Sample\`** にある
   （`build-app.ps1` の sln パス `…\WebForms_Sample\WebForms_Sample.sln` は外側＝別階層）。外側を `/path` にすると
   `Web.config` の無い階層を配信して詰まる。

2. **`OT_RESOURCE_ROOT` を iisexpress プロセスへ確実に渡す。** User スコープ環境変数は新規プロセスに
   継承されるが、`SetEnvironmentVariable(...,'User')` の直後は同一セッションにまだ載っていないことがある。
   **起動コマンドで明示する**と確実：

   ```powershell
   $env:OT_RESOURCE_ROOT = "<repo>\resource"
   & $iisexpress /path:"<repo>\WebForms_Sample\WebForms_Sample" /port:8080 /clr:v4.0   # Web.config のある内側
   ```

## スモークテスト対象と判定

- `Aspx/Framework/Ping.aspx` … 未認証で **302**（→ login へ）。正常。
- `Aspx/start/login.aspx` … **200** でログインフォームが描画されれば OK。
- **★ 初回リクエストは待つ**：ビルド直後の**初回リクエストは初回コンパイル**（WebForms＝`.aspx` コンパイル／core＝JIT・起動）で
  **30 秒を超える**ことがある（実測：`/Ping/Index` が 30s タイムアウト→ウォーム後は正常）。**タイムアウト＝失敗と誤判定しない**
  ＝初回は **120s 程度のタイムアウト**にするか、**1発ウォームアップしてから判定**する。
- **★ `app.config`（`<appSettings file="app.config">` の外部ファイル）を書き換えたら iisexpress を起こし直す**：WebForms は `Web.config` の `<appSettings file="app.config"/>` で外部ファイルを読むが、**この外部ファイルの変更は ASP.NET の再起動監視の対象外**＝直しても直前の設定で動き続ける（実測）。config を変えて再検証するなら **iisexpress を止めて起こし直す**（または `Web.config` 本体を touch して app ドメインを再起動させる）。知らないと「直したのに直っていない＝手順が誤りに見える」。
- **500 が出たら resource パス／config 解決の失敗を疑う**（フレームワーク初期化で XML 定義・log4net を
  `%OT_RESOURCE_ROOT%` から読む＝ここが実行時検証の勘所。⑥ / `references/resource-config.md`）。
  **典型症状＝`System.ArgumentException: リソースファイル[…]は見つかりませんでした。`（`at Touryo.Infrastructure.Public.IO.ResourceLoader.Exists`）**。
  `%OT_RESOURCE_ROOT%` が**プロセスに載っておらず空展開**し、パス先頭（ルート）が欠けたときに出る
  （例：`リソースファイル[\Log\SampleLogConf.xml]は見つかりませんでした`）。原因＝常駐シェルが `SetEnvironmentVariable`
  より前に起動し古い環境ブロックを継承したケース等 → **手順2 のとおり起動コマンドで `$env:OT_RESOURCE_ROOT` を明示**する。

## ★ 302 を非対話で正しく測る（PS7 の罠が2つ）

スモークの合格基準は**生のステータスコード**（`Ping.aspx`＝302→login／net48 MVC の `Ping/Index`＝302）だが、
PowerShell で素直に書くと**2通りとも間違える**：

1. `Invoke-WebRequest` は**既定でリダイレクトを追う**ので、302 が追跡後の **200 に化ける**（→「スキルの記述が誤り」と誤診する）。
2. 止める `-MaximumRedirection 0` は `-SkipHttpErrorCheck` と併用すると、PS7 では**全リクエストが**
   `Operation is not valid due to the current state of the object` で落ちる（2xx でも発生＝サーバは正常なのに「実行失敗」に見える）。

→ **`HttpClient` で追跡を切って測る**（実測で安定）：

```powershell
$h = [System.Net.Http.HttpClientHandler]::new(); $h.AllowAutoRedirect = $false
$c = [System.Net.Http.HttpClient]::new($h); $c.Timeout = [TimeSpan]::FromSeconds(150)
$r = $c.GetAsync("http://localhost:$Port$path").Result
"{0} {1}" -f [int]$r.StatusCode, $r.Headers.Location
```

## ★ WebForms のポストバック検証は hidden を全件返す

WebForms を**非対話でポストバック**（ボタン押下相当）で叩くとき、**GET で受け取った `<input type="hidden">` を全件そのまま次の POST に載せる**。
`__VIEWSTATE`/`__EVENTVALIDATION` だけを返すと、フレームワークが持つ **`ctl00$RequestTicketGuid`・`ScreenGuid`・`WindowGuid`・`SubmitFlag`** 等が欠けて
**`FrameworkException:不正操作チェック処理でエラーが発生しました。`** になる（実測。ビルドも設定も正しいのに「実行失敗」に見える＝紛らわしい）。
＝MVC 側の antiforgery（下記）と対。

- **★ 押すボタンの name はマスタページ側のことがある**：「件数取得」等の submit は `ctl00$ContentPlaceHolder…$…` でなく
  **`ctl00$btnMButton1`（マスタページ上のフッタ ボタン）**だったりする。非対話では **`<input type="submit">` を列挙して name を拾う**
  （その name を `__EVENTTARGET` 相当のキーとして POST に載せる。hidden 全件返しと併用）。
- **★ YES/NO 確認ダイアログの YES を非対話で押す**（`opentouryo-webforms-dialog`）：ダイアログは別ページで、YES は `window.parent.Fx_CallbackOfYesNoMessageDialog(2)` が **`ctl00$SubmitFlag`** を設定して**親フォームをボタン名なしで submit** する（値＝`1`=×／`2`=YES／`3`=NO。`Scripts/touryo/common.js`）。→ 非対話の YES は「**直前ページの hidden 全件 ＋ `ctl00$SubmitFlag=2` を親 URL へ POST**」。確認ダイアログを含む画面（追加→YES→INSERT 等）はこれで検証できる。
- **★ ポストバック検証は StateServer 稼働が前提（＝昇格不可なら一時 InProc）**：ログインで `Session["nonce"]` を書くため、
  ASP.NET State Service 未起動だと **`HttpException:セッション状態要求を…作成できませんでした`（500）** で止まり、以降の検証に入れない。
  起動は**要管理者**（`opentouryo-project-setup-config` ⑦）。昇格できないときは **`Web.config` の `sessionState` を一時的に `InProc` に変えて検証し、
  直後に `StateServer` へ戻す**（**作業ツリーは `StateServer` のまま残す**＝⑦ の方針を壊さない）。セッションに触れないパス
  （`/`・`/Home/Index`・`/Ping/Index`・`Ping.aspx`）のスモークは**未起動でも通る**（InProc 化は postback を伴う検証のときだけ）。

## ★ 自動スモークの罠：分離レベルの先頭 option は `NC`（NotConnect）

CRUD 画面を機械的に叩くとき「各 `<select>` の**先頭 option** を選ぶ」実装だと、**分離レベルの先頭が `NC`＝NotConnect**（接続しない）で、
B層が Dam を作らず、D層 `SetSqlByFile2` で **`NullReferenceException`→500**（`GetDam()` が null）になる。サンプルの既定は `NT`（`Selected=true`）。
どちらかで回避する：

- **(a) 既定 option（`selected="selected"`）を選ぶ** — ただし `Html.DropDownListFor` は `selected` を `value` より**前**に描画するので、
  素朴な正規表現だと拾えない。
- **(b) 分離レベルは `NT`/`RC` を明示指定する**。

（上流の軽微な難点：`NC` は UI から選べるのに DAO を呼ぶアクションでは必ず未処理例外になる＝業務例外にできると親切。）

## core（net10.0）＝ Kestrel（`dotnet run`）

core は IIS Express ではなく Kestrel。**`dotnet run` は `Properties\launchSettings.json` の `applicationUrl` を優先する**ため、
`ASPNETCORE_URLS` を環境変数で与えても**無視される**ことがある（実測：`5080` を渡したが profile の `5219` で起動）。
ポートを固定するには：

- `dotnet run --urls http://localhost:5080`（または `--launch-profile <名>` でプロファイルを明示）
- あるいは **launchSettings のポート（`http` プロファイルの `applicationUrl`）をそのまま使う**（そこに出るポートで開く）

```powershell
$env:OT_RESOURCE_ROOT = "<repo>\resource"   # dotnet run を起こすシェルで設定してから実行
dotnet run --project "<repo>\MVC_Sample_Core\MVC_Sample" --urls http://localhost:5080
```

**★ core MVC のスモーク判定は net48 と違う**：`HomeController` は class に `[Authorize]` だが `Index`/`Login` は `[AllowAnonymous]`、
`PingController` は素の `Controller`（`[Authorize]` 無し）＝**`/`・`/Home/Index`・`/Home/Login`・`/Ping/Index` はすべて 200**
（未認証でも 302 にならない。**net48 MVC は `Ping/Index`=302**＝同名サンプルでもランタイムで違う）。
**判定は「200 が返り、かつ `ACCESS` ログにフィルタのトレース（`OnActionExecuting` 等）が出ること」**＝ログに出て初めて
基盤初期化（`%OT_RESOURCE_ROOT%` 解決）の成功が言える（200 だけでは resource/config 解決の成否は分からない）。
500＝resource/config 解決失敗の見方は net48 と同じ。**core は `InitConfiguration()` 必須**（⑦）。

**★ core MVC の DB 到達確認は antiforgery 込みの POST（非対話手順）**：`GET /Home/Login` で **`__RequestVerificationToken`**
（`name="__RequestVerificationToken"` の hidden ＋ 同名 Cookie）を拾い、それを載せて **POST /Home/Login** → **セッション（Cookie）を維持**して
**POST /Crud1/SelectCount**（`DdlIso=RC` を明示＝先頭 `NC` を避ける）。成功＝「3件のデータがあります」＋`SQLTRACE` に `SELECT COUNT(*)`。
**トークンと Cookie を引き回さないと弾かれる**（WebForms の hidden 全件返しと対の、MVC 版の非対話手順）。
- **★ ログインのフォーム項目名**（net48/core 共通・実測）：ユーザ名＝**`UserName`**（`UserId` ではない）／**submit ボタン名 `normal` も送る**（`HomeController.Login` は `Request.Form.Keys.Any(x=>x=="external")` で分岐＝通常ログインは `normal`）。`Crud1/SelectCount` の項目は `DdlDap`/`DdlMode1`/`DdlMode2`/`DdlIso`/`DdlExRollback`。
- **★ core は日本語をエンコードして返す＝判定前にデコードする**（ランタイム非対称）：**Razor 出力は数値文字参照**（`3&#x4EF6;…`）＝リテラル「3件のデータがあります」を検索すると0件で**成功を失敗と誤判定**。さらに **`@Json.Serialize`（JS ダイアログ経路）は `System.Text.Json` 既定で非 ASCII を `\uXXXX` にエスケープ**する。→ **判定は HTML エンティティと `\uXXXX` の両方をデコードしてから照合**する（net48 は素のまま返る＝デコード不要。画面はブラウザが復元＝アプリの不具合ではない）。

**★ ただしアクション URL への直接 POST「だけ」で合否を判定しない（MVC 固有）**：`POST /Xxx/SelectCount` を直接叩くのはボタンを経由しないので、
**submit ボタンがフォームに紐付いていなくても必ず緑になる**（`@section` に置いたフッタ ボタンが `<form>` の外に出ていても素通り＝`opentouryo-layer-p-mvc` の `@section` 罠）。
ボタン経由の動作まで見るには、**生成 HTML から各 submit の所属フォーム（`<form>` 内包 or `form="<実在ID>"`）を解決して押下を再現する**
（どのフォームにも属さないボタンは NG）。ビルドも `aspnet_compiler` も通るため、直接 POST と併せて紐付けも検証する。

## デスクトップ（WinForms / WPF・2CS・リッチクライアント）＝ exe

Web ではないので HTTP スモークは無い。**exe を起動してプロセスが生存する（起動時クラッシュしない）ことを確認**する
（初期化で resource/config・log4net を読むため、設定ミスは起動時例外として出る＝ここが検証点）。

**合格基準**：exe を **`OT_RESOURCE_ROOT` を渡して起動**し、**数秒（目安 5–7s）プロセスが生存**して初期画面
（ログイン等）が出れば **startup OK**（初期化＝resource/config 解決を通過）。起動直後に異常終了・未処理例外ダイアログは
**NG**＝resource/config・参照解決の失敗を疑う（stderr / イベントログ）。
**DB 依存操作は条件付き**（`SqlTextFilePath` の SQL 実行・接続文字列先の SQL Server(Northwind) 等）：**DB があれば
結果（件数など）まで確認する**／**無ければ対象外**（未起動の失敗は Web の `/Ping`・Crud の DB 前提タイムアウトと同扱いで、
セットアップの不備ではない）。DB は選択式 `opentouryo-project-setup-db` で立てられる（既定が SQL Server/Northwind と一致）。

- exe の場所：net48＝`bin\Debug\<app>.exe`、core＝`bin\Debug\net10.0-windows7.0\<app>.exe`（`dotnet run --project <proj>` でも可）。
  **★ ただし断定せず csproj の `OutputPath` を見る**：例 `WCFService` は `OutputPath=bin\`（`Debug` サブフォルダ無し）＝`bin\<app>.exe`。「`bin\Debug\` に無い＝ビルド失敗」と誤判定しない。
- **★ 2CS 等のログは `resource\Log\` でなく exe と同じフォルダに出る**（同梱ログ定義の `File` が相対名 `ACCESS_2CS` 等＝
  `references/resource-config.md` の埋め込み/相対）。起動生存を裏取りするときは **`bin\Debug\*.log`** を見る
  （Web の癖で `resource\Log` を見ると「ログが出ない＝失敗」と誤判定する）。
- **非対話チェック**（起動生存を機械判定）：

  ```powershell
  $env:OT_RESOURCE_ROOT = "<repo>\resource"
  $exe = "<exe>"
  # ★ -WorkingDirectory を必ず付ける：付けないと CWD が exe フォルダにならず、相対名で参照する定義ファイル
  #   （WSClient の TMProtocolDefinition2.xml / TMInProcessDefinition.xml 等）が解決できず、
  #   CallController の TypeInitializationException（内部 FileNotFoundException）で画面が出ない。
  #   手で（エクスプローラから）起動すると再現しない＝エージェント/CI だけが踏む（実測）。
  $p = Start-Process $exe -WorkingDirectory (Split-Path -Parent $exe) -PassThru
  Start-Sleep -Seconds 6
  if ($p.HasExited) { throw "起動直後に終了（startup NG）＝resource/config を確認" }
  $p.Kill()   # 生存＝startup OK
  ```

- **★ GUI を UI Automation で操作して DB 到達まで見るなら手当てが要る**（起動生存までは上記で足りる）：OpenTouryo のリッチクライアントのボタンは
  UIA から **`ControlType.Pane`** に見え `InvokePattern` を持たない・**`Panel` に載せたフッタ ボタンは UIA ツリーに現れない**（実測）。
  → **座標クリック**（`BoundingRectangle`／クライアント座標）と**キーボード**（`^{END}`→`{HOME}`/`{TAB}`→`SPACE`）を併用する。

- **★ 実アセンブリを外から叩くハーネス**（別 exe で app の DLL を参照し B/D 層や結線を直接検査する等）**は、`.exe.config` と「埋め込みリソースのエントリ アセンブリ依存」を必ず合わせる**（実測）。
  合わないと**アプリ側の回帰に化ける**：`.exe.config` が無いと接頭辞定義（`FxPrefixOf*`）が読めず結線数が 0 になる／埋め込みログ定義は**エントリ アセンブリ基準**で解決されるため、
  エントリが `<Harness>.exe` になると `リソースファイル[…SampleLogConf2CS.xml]は見つかりませんでした` で `Form_Load` が例外→**残りの `Load` ハンドラが呼ばれず、例外は `Application.ThreadException` に回って黙って消える**。
  → ハーネスに app の `.exe.config` を揃え、`FxLog4NetConfFile` はファイル指定にする。

- **3層リッチクライアント（`WSClient_*`）は WS ホスト側の起動も要る**：WS ホスト＝`WS_sample\ServiceInterface`
  （既定 `ASPNETWebService`）を起動してからクライアント exe を起動する。ホストの引き込み・張替は
  `opentouryo-project-setup-core` の `samples/webservices.md`（③ WS ホスト節）。ホスト未起動ならインプロセス兼用で開ける。
  - **★ WS ホストの稼働は GUI 無しで機械判定できる**：既定 `IISUrl=https://localhost:44349/` は証明書が要るので、
    WebForms と同じく**プレーン HTTP ポートで起動**する（`iisexpress /path:"<host dir>" /port:8082 /clr:v4.0`）。判定＝
    **`GET /test`（`FxController`）が 200＋固定 JSON**／**`GET /WebAPIControllerForFx` が 405**（POST 専用＝ルート生存の証拠）。
    **`GET /`（既定ドキュメント無し）はタイムアウトするので判定に使わない**。実 WS 呼び出し（既定 `protocol="5"` の Web API）は
    クライアント GUI 起点＝到達点は「ホスト稼働＋クライアント起動生存」まで（`samples/webservices.md`）。
  - **★ 初回プローブは 503（Service Unavailable）を返しうる**（実測：1回目 503→数秒後 200）＝**503 はリトライしてから判定**（単発の 503 を結論にしない）。**ウォームアップは `GET /`（タイムアウトする）でなく判定対象パス（`GET /test`）で行う**——`/` でウォームアップするとタイムアウト待ちで時間を食い潰し、本番プローブが起動中に当たって 3連続 503＝失敗に見える。

## バッチ / CLI（コンソール）＝ exe（引数あり）

- **実行前にサンプルの `readme.txt` で必要なコマンド引数を確認する。** バッチ/CLI は**引数必須**のことがあり、
  無引数だと `Program.cs` の `argsDic["/DAP"]` 等で **`KeyNotFoundException`**（一見「実行失敗」だが実体は引数不足）。
  例：`SimpleBatch_sample` は `readme.txt` に `/Dap SQL /Mode1 individual /Mode2 static /EXROLLBACK -`
  （`RerunnableBatch_sample` は引数不要）。
- **DB スキーマ前提も確認する（サンプル同梱の `CREATE *.sql` を探して適用）。** 例：`RerunnableBatch_sample` は
  Northwind に **`ORDERS2` テーブルが必要**（同梱 `CREATE ORDERS2.sql`）。`opentouryo-project-setup-db` が立てる
  Northwind に**サンプル固有の追加テーブルは含まれない**＝同梱 SQL を別途流す。
- **合格基準**：引数を与えて起動し、**framework 初期化（log4net 等）＋業務ロジック到達＝OK**（標準出力に処理結果、
  例「3件のデータがあります」）。**DB があれば結果（件数）まで確認**／無ければ初期化＋到達まで（上の「DB 依存は条件付き」）。
- **★ exit code で判定しない。** サンプルは末尾で `Console.ReadKey()` を呼ぶため、**非対話（stdin リダイレクト）だと
  成功分岐でも `InvalidOperationException` で exit code が非ゼロ**（`0xE0434352` / -532462766）になる（業務処理は
  成功済み＝サンプルコード都合。`SimpleBatch`/`RerunnableBatch` 系共通・**net48/net10.0 両ランタイムで実測**）。
  **成否は標準出力で判定**する（`< nul` で stdin を与えても ReadKey 例外は避けられない。出力で見る）。
- **★ 認証付き CLI（`DAG_Login_CLI`/`LIR_Login_CLI`）の非対話スモークは `--help`（exit 0）で見る。** 引数無しの既定
  （RootCommand）ハンドラは `Prompt.Confirm(...)`（Sharprompt）で**対話待ちにブロック**し、`login` サブコマンドは
  **IdP（`MultiPurposeAuthSite:44300`）稼働が前提**。よって実 OAuth フローはセットアップ範囲外＝到達点は「ビルド＋`--help` OK」まで。

