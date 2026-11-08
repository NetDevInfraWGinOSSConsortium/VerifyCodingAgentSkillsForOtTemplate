# opentouryo-test-e2e-web：コードの見本

MVC_Sample（net10.0）で実測した形。`<Web>` は Web のプロジェクト名（例 `MVC_Sample`）。

## csproj（`<Web>.E2ETests/<Web>.E2ETests.csproj`）

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>disable</Nullable>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="18.10.1" />
    <PackageReference Include="NUnit" Version="4.6.1" />
    <PackageReference Include="NUnit3TestAdapter" Version="6.3.0" />
    <PackageReference Include="Microsoft.Playwright" Version="1.63.0" />
    <!-- Web の csproj と同じ版にする（脆弱性の対策で足している依存も同じものを足す） -->
    <PackageReference Include="Microsoft.Data.SqlClient" Version="7.0.0" />
    <PackageReference Include="System.Security.Cryptography.Pkcs" Version="10.0.13" />
  </ItemGroup>
  <!-- Web のプロジェクト・OpenTouryo の DLL は参照しない（外から操作する） -->
</Project>
```

`QualityAttributes.cs`（`[Basis]`・`[Observation]`）は、`<Web>.Tests` のものを写し、名前空間を `<Web>.E2ETests` にする。

## アプリの起動とブラウザ（`AppHost.cs`）

```csharp
using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Threading.Tasks;
using Microsoft.Playwright;
using NUnit.Framework;

namespace <Web>.E2ETests
{
    /// <summary>テストの間だけアプリを起動し、ブラウザを用意する（名前空間の全テストに 1 回）</summary>
    [SetUpFixture]
    public class AppHost
    {
        public static string BaseUrl { get; private set; }
        public static IBrowser Browser { get; private set; }

        /// <summary>テストの出力（bin/Debug/net10.0）から Web のプロジェクトのフォルダへ</summary>
        public static string WebDir => Path.GetFullPath(Path.Combine(
            TestContext.CurrentContext.TestDirectory, "..", "..", "..", "..", "<Web>"));

        private static Process app;
        private static IPlaywright playwright;

        [OneTimeSetUp]
        public async Task StartAsync()
        {
            BaseUrl = "http://127.0.0.1:" + FreePort();

            var psi = new ProcessStartInfo("dotnet", "run --no-launch-profile --urls " + BaseUrl)
            {
                WorkingDirectory = WebDir,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };
            psi.Environment["ASPNETCORE_ENVIRONMENT"] = "Development";
            // OT_RESOURCE_ROOT など、appsettings.json が参照する環境変数は、テストを実行するシェルから引き継ぐ

            app = Process.Start(psi);
            app.OutputDataReceived += (s, e) => { if (e.Data != null) TestContext.Progress.WriteLine("[app] " + e.Data); };
            app.ErrorDataReceived += (s, e) => { if (e.Data != null) TestContext.Progress.WriteLine("[app:err] " + e.Data); };
            app.BeginOutputReadLine();
            app.BeginErrorReadLine();

            // ログインの要らない URL が 200 を返すまで待つ（MVC_Sample は /Ping）
            using (var http = new HttpClient())
            {
                var deadline = DateTime.Now.AddMinutes(3);
                while (true)
                {
                    if (app.HasExited) throw new InvalidOperationException("アプリが起動しなかった（exit " + app.ExitCode + "）");
                    try
                    {
                        var res = await http.GetAsync(BaseUrl + "/Ping");
                        if (res.StatusCode == HttpStatusCode.OK) break;
                    }
                    catch (HttpRequestException) { }
                    if (DateTime.Now > deadline) throw new TimeoutException("アプリが応答しない: " + BaseUrl);
                    await Task.Delay(500);   // 起動の待ち合わせだけ。テストの中では固定の時間を待たない
                }
            }

            playwright = await Playwright.CreateAsync();
            // Edge のチャネル（Windows に標準。Playwright の chromium の版に縛られない）
            Browser = await playwright.Chromium.LaunchAsync(new BrowserTypeLaunchOptions { Headless = true, Channel = "msedge" });
        }

        [OneTimeTearDown]
        public async Task StopAsync()
        {
            if (Browser != null) await Browser.DisposeAsync();
            playwright?.Dispose();
            if (app != null && !app.HasExited)
            {
                app.Kill(entireProcessTree: true);   // dotnet run の子（アプリ）まで止める
                app.WaitForExit(10000);
            }
        }

        private static int FreePort()
        {
            var l = new TcpListener(IPAddress.Loopback, 0);
            l.Start();
            int port = ((IPEndPoint)l.LocalEndpoint).Port;
            l.Stop();
            return port;
        }
    }
}
```

## データの準備（`TestDb.cs`）

```csharp
using System;
using System.IO;
using System.Text.Json;
using Microsoft.Data.SqlClient;

namespace <Web>.E2ETests
{
    /// <summary>テストのデータの準備・後始末（テストから直接 SQL。接続文字列は Web の appsettings.json から読む）</summary>
    public static class TestDb
    {
        private static string connectionString;

        private static string ConnectionString
        {
            get
            {
                if (connectionString == null)
                {
                    string path = Path.Combine(AppHost.WebDir, "appsettings.json");
                    var options = new JsonDocumentOptions { CommentHandling = JsonCommentHandling.Skip, AllowTrailingCommas = true };
                    using (var doc = JsonDocument.Parse(File.ReadAllText(path), options))
                    {
                        // キーは appsettings.json の綴りどおり（大文字・小文字を区別する）
                        connectionString = doc.RootElement.GetProperty("connectionStrings")
                            .GetProperty("ConnectionString_SQL").GetString();
                    }
                }
                return connectionString;
            }
        }

        public static object Scalar(string sql, params (string, object)[] ps)
        {
            using (var cn = new SqlConnection(ConnectionString))
            using (var cmd = new SqlCommand(sql, cn))
            {
                foreach (var (n, v) in ps) cmd.Parameters.AddWithValue(n, v ?? DBNull.Value);
                cn.Open();
                return cmd.ExecuteScalar();
            }
        }
    }
}
```

## テストの骨格

```csharp
using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Playwright;
using NUnit.Framework;
using static Microsoft.Playwright.Assertions;

namespace <Web>.E2ETests
{
    /// <summary>受注一覧（SC-ORD-01）の画面のテスト。仕様：docs/spec/<名前>-tests.md（<仕様>@<版>）</summary>
    public class OrdListScreenTests
    {
        private static readonly Random Rnd = new Random();
        private IBrowserContext context;
        private IPage page;
        private string cust;

        [SetUp]
        public async Task SetUpAsync()
        {
            // テスト用の顧客と、その受注 25 件（20 件で 1 ページなら 2 ページ）。キーは列の型と書式に合わせて作る
            // 受注日は B層のテスト（2199 年）と重ならない範囲（並行して動くため）
            cust = new string(Enumerable.Range(0, 5).Select(_ => (char)('A' + Rnd.Next(26))).ToArray());
            TestDb.Scalar("INSERT INTO Customers (CustomerID, CompanyName) VALUES (@c, @n)", ("@c", cust), ("@n", "E2E-" + cust));
            for (int i = 0; i < 25; i++)
                TestDb.Scalar("INSERT INTO Orders (CustomerID, EmployeeID, OrderDate, ShipVia, Freight) VALUES (@c, 1, @d, 1, 0)",
                    ("@c", cust), ("@d", new DateTime(2198, 1, 1).AddDays(i)));

            context = await AppHost.Browser.NewContextAsync(new BrowserNewContextOptions { BaseURL = AppHost.BaseUrl });
            page = await context.NewPageAsync();

            // ログイン（アプリごとに、ログインの画面とコントローラを読んで書く）
            await page.GotoAsync("/Home/Login");
            await page.FillAsync("#UserName", "e2e");
            await page.FillAsync("#Password", "x");
            await page.ClickAsync("input[name=normal]");
            await page.WaitForLoadStateAsync(LoadState.NetworkIdle);
        }

        [TearDown]
        public async Task TearDownAsync()
        {
            await context.CloseAsync();                       // ブラウザを閉じてから
            TestDb.Scalar("DELETE FROM Orders WHERE CustomerID = @c", ("@c", cust));      // 子から消す
            TestDb.Scalar("DELETE FROM Customers WHERE CustomerID = @c", ("@c", cust));
        }

        [Test, Basis("EV-ORD-104"), Basis("SC-ORD-01-B05")]
        public async Task ページ切替_次で2ページ目()
        {
            await page.GotoAsync("/OrdTf");
            await page.SelectOptionAsync("#CustomerID", cust);   // テストが入れたデータだけが出る条件
            await page.ClickAsync("#btnMain1");                   // 検索（画面のボタンを押す）
            await Expect(page.Locator("#pageInfo")).ToHaveTextAsync("1 / 2 ページ");

            // ここから下は Green の形（段 4 でボタン #pageNext を付けた後。Red ではここで落ちる）
            await Expect(page.Locator("#pageNext")).ToBeEnabledAsync();
            await page.ClickAsync("#pageNext");
            await Expect(page.Locator("#pageInfo")).ToHaveTextAsync("2 / 2 ページ");
            await Expect(page.Locator("#pageNext")).ToBeDisabledAsync();   // 境界の反対側
        }
    }
}
```

Red（ボタンがまだ無い）では、`ToBeEnabledAsync` が 5 秒で次のように落ちる（実測）。これが Red の正しい落ち方。

```text
Microsoft.Playwright.PlaywrightException : Locator expected to be enabled
Call log:
  - Expect "ToBeEnabledAsync" Locator("#pageNext") with timeout 5000ms
  - waiting for Locator("#pageNext")
```
