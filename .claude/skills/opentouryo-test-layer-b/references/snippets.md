# コピー元スニペット（B層のルート メソッドの単体テスト）

`<Web>` は Web のプロジェクト名（例 `MVC_Sample`）、`<名前空間>` は Web のプロジェクトのルート名前空間。
HintPath の `..\..\OpenTouryoAssemblies\…` は、**Web のプロジェクトの csproj の HintPath と同じ場所**に合わせる。
<!-- as-built：2026-11-06。ASP.NET MVC 5（net48）・Web Forms（net48）・ASP.NET Core MVC（net10.0）で、この形のまま全件通した。 -->

## csproj（net10.0。ASP.NET Core MVC）

`<Web>.Tests\<Web>.Tests.csproj`

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
  </ItemGroup>
  <ItemGroup>
    <Reference Include="OpenTouryo.Business">
      <HintPath>..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\OpenTouryo.Business.dll</HintPath>
    </Reference>
    <Reference Include="OpenTouryo.Framework">
      <HintPath>..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\OpenTouryo.Framework.dll</HintPath>
    </Reference>
    <Reference Include="OpenTouryo.Public">
      <HintPath>..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\OpenTouryo.Public.dll</HintPath>
    </Reference>
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\<Web>\<Web>.csproj" />
  </ItemGroup>
</Project>
```

## csproj（net48。ASP.NET MVC 5・Web Forms）

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net48</TargetFramework>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="18.10.1" />
    <PackageReference Include="NUnit" Version="4.6.1" />
    <PackageReference Include="NUnit3TestAdapter" Version="6.3.0" />
    <!-- 版は <Web>\packages.config と同じ。無いと SNI（ネイティブ）が写らず DllNotFoundException -->
    <PackageReference Include="Microsoft.Data.SqlClient" Version="7.0.0" />
  </ItemGroup>
  <ItemGroup>
    <Reference Include="OpenTouryo.Business">
      <HintPath>..\..\OpenTouryoAssemblies\Build_net48\OpenTouryo.Business.dll</HintPath>
    </Reference>
    <Reference Include="OpenTouryo.Framework">
      <HintPath>..\..\OpenTouryoAssemblies\Build_net48\OpenTouryo.Framework.dll</HintPath>
    </Reference>
    <Reference Include="OpenTouryo.Public">
      <HintPath>..\..\OpenTouryoAssemblies\Build_net48\OpenTouryo.Public.dll</HintPath>
    </Reference>
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\<Web>\<Web>.csproj" />
  </ItemGroup>
  <ItemGroup>
    <!-- Web.config が <appSettings file="app.config"/> のときだけ。app.config（appSettings の断片）をそのまま使う -->
    <None Include="..\<Web>\app.config" Link="<Web>.appSettings.config" CopyToOutputDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
```

## App.config（net48）

`<Web>.Tests\App.config`。`connectionStrings` は `<Web>\Web.config` から写す（パスワード等は Web.config と同じ扱い）。

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <connectionStrings>
    <add name="ConnectionString_SQL" connectionString="（Web.config と同じ）"/>
  </connectionStrings>
  <!-- Web.config が <appSettings file="app.config"/> なら、リンクした断片を読む。
       そうでなければ、ここに <appSettings> の中身を Web.config から写す -->
  <appSettings file="<Web>.appSettings.config"/>
</configuration>
```

## TestSetup.cs（net10.0 だけ）

```csharp
using Microsoft.Extensions.Configuration;
using NUnit.Framework;
using Touryo.Infrastructure.Public.Util;

namespace <名前空間>.Tests
{
    /// <summary>テスト全体の前処理</summary>
    [SetUpFixture]
    public class TestSetup
    {
        /// <summary>Web の appsettings.json（テストの出力へ写る）をライブラリに渡す。Startup と同じ。</summary>
        [OneTimeSetUp]
        public void OneTimeSetUp()
        {
            GetConfigParameter.InitConfiguration(
                new ConfigurationBuilder()
                    .SetBasePath(TestContext.CurrentContext.TestDirectory)
                    .AddJsonFile("appsettings.json")
                    .Build());
        }
    }
}
```

## QualityAttributes.cs（[Basis]・[Observation]）

```csharp
using System;
using NUnit.Framework;

namespace <名前空間>.Tests
{
    /// <summary>検証：期待値の根拠（仕様の ID・業務ルール）。**消すと「期待値の変更」になる。**</summary>
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true, Inherited = false)]
    public sealed class BasisAttribute : PropertyAttribute
    {
        /// <param name="source">根拠（例 "EV-ORD-101"・"VAL-ORD-03"）</param>
        public BasisAttribute(string source) : base("Basis", source) { }
    }

    /// <summary>観測：期待値が、今の振る舞いを写したもの（根拠が無い）。理由を書く。</summary>
    [AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false, Inherited = false)]
    public sealed class ObservationAttribute : PropertyAttribute
    {
        /// <param name="reason">観測にした理由</param>
        public ObservationAttribute(string reason) : base("Observation", reason) { }
    }
}
```

## テストの骨格

`<LayerB>`・`<業務>ParameterValue`・`<業務>ReturnValue`・`<Method>`・テーブルと列は、テストする B層に合わせる。
（net48・net10.0 共通。net48 でも書き換えずに通る形にしてある）

```csharp
using System;
using Microsoft.Data.SqlClient;
using NUnit.Framework;
using Touryo.Infrastructure.Business.Util;
using Touryo.Infrastructure.Framework.Exceptions;
using Touryo.Infrastructure.Public.Db;
using Touryo.Infrastructure.Public.Util;

namespace <名前空間>.Tests
{
    public class <LayerB>Tests
    {
        /// <summary>このテストが入れたデータのキー（他と衝突しない）</summary>
        private string key;

        [SetUp]
        public void SetUp()
        {
            // キーは列の型と書式に合わせる（SKILL の「データの準備と後始末」）。これは幅のある文字列の列（nvarchar(40)）の例
            key = "T-" + Guid.NewGuid().ToString("N").Substring(0, 10);
            // 前提のデータが要るなら、ここで key を使って入れる（Exec を参照）
        }

        [TearDown]
        public void TearDown()
        {
            // 失敗したテストの後でも消える。親子のあるデータは子から消す（明細 → 受注 → 顧客）
            Exec("DELETE FROM Shippers WHERE CompanyName = @key");
        }

        [Test, Basis("EV-XXX-101")]
        public void <Method>_正常()
        {
            var rv = Call("<Method>", "SQL", pv => { /* pv の入力を key で詰める */ });

            Assert.That(rv.ErrorFlag, Is.False);
            Assert.That(Scalar("SELECT COUNT(*) FROM Shippers WHERE CompanyName = @key"), Is.EqualTo(1));
        }

        [Test, Basis("ERR-XXX-01")]
        public void <Method>_業務エラーはロールバックされる()
        {
            var rv = Call("<Method>", "SQL", pv => { /* 業務エラーになる入力 */ });

            Assert.That(rv.ErrorFlag, Is.True);
            Assert.That(rv.ErrorMessageID, Is.EqualTo("<仕様のメッセージ ID>"));
            Assert.That(Scalar("SELECT COUNT(*) FROM Shippers WHERE CompanyName = @key"), Is.EqualTo(0));
        }

        [Test, Basis("ERR-XXX-02")]
        public void <Method>_システムエラー()
        {
            // new Action(() => { …; }) と書く（() => … は net48 で CS0121、new TestDelegate は net10.0 で CS0618）
            var ex = Assert.Catch<BusinessSystemException>(new Action(() => { Call("<Method>", "SQL", pv => { }); }));
            Assert.That(ex.messageID, Is.EqualTo("<仕様のメッセージ ID>"));
        }

        /// <summary>DoBusinessLogic の境界で呼ぶ（UOC_ は直接呼ばない）</summary>
        private static <業務>ReturnValue Call(string method, string actionType, Action<<業務>ParameterValue> fill)
        {
            var pv = new <業務>ParameterValue("<LayerB>Tests", "-", method, actionType, new MyUserInfo("test", "127.0.0.1"));
            fill(pv);
            return (<業務>ReturnValue)new <LayerB>().DoBusinessLogic(pv, DbEnum.IsolationLevelEnum.User);
        }

        /// <summary>準備・後始末・確かめは、B層を通さずに直接 SQL で行う</summary>
        private int Exec(string sql)
        {
            using (var cn = new SqlConnection(GetConfigParameter.GetConnectionString("ConnectionString_SQL")))
            using (var cmd = new SqlCommand(sql, cn))
            {
                cmd.Parameters.AddWithValue("@key", key);
                cn.Open();
                return cmd.ExecuteNonQuery();
            }
        }

        private int Scalar(string sql)
        {
            using (var cn = new SqlConnection(GetConfigParameter.GetConnectionString("ConnectionString_SQL")))
            using (var cmd = new SqlCommand(sql, cn))
            {
                cmd.Parameters.AddWithValue("@key", key);
                cn.Open();
                return Convert.ToInt32(cmd.ExecuteScalar());
            }
        }
    }
}
```

- net10.0 の `Microsoft.Data.SqlClient` は、Web のプロジェクトの `PackageReference` から引き継がれる（足さなくてよい。実測）。
- `IsolationLevelEnum.User` は、親クラス2 がプロジェクトの既定へ振り替える（`opentouryo-layer-b`）。P層が別の値を渡しているなら、それに合わせる。
