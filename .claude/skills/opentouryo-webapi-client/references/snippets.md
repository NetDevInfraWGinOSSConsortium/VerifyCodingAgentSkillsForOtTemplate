# コピー元スニペット：Web API クライアント

`opentouryo-webapi-client` の実装コード。表は `Suppliers` を例にした worked example。
出典＝サンプル `Frameworks\Tests\TestWebAPIClient`（実ソースで裏取り。サンプルは `HttpWebRequest`＋自前 JSON。下は `HttpClient` 版に整理）。

## HTTP 呼び出し（Bearer 対応）

```csharp
using System.Net.Http;
using System.Net.Http.Headers;

static readonly HttpClient Http = new HttpClient();
static string BaseUrl = "http://localhost:51087";
static string Token   = null;   // opentouryo-oauth2-client で取得。None 許可のサーバなら null 可

static void SetBearer()
{
    Http.DefaultRequestHeaders.Authorization =
        string.IsNullOrEmpty(Token) ? null : new AuthenticationHeaderValue("Bearer", Token);
}

// 疎通（GET /api/<ctrl>/test）
static (int status, string body) Get(string url)
{
    HttpResponseMessage r = Http.GetAsync(url).Result;   // 4xx/5xx でも本文を読む
    return ((int)r.StatusCode, r.Content.ReadAsStringAsync().Result);
}

// POST（JSON＝[FromBody] のアクション）
static (int status, string body) PostJson(string url, string json)
{
    var content = new StringContent(json ?? "", System.Text.Encoding.UTF8, "application/json");
    HttpResponseMessage r = Http.PostAsync(url, content).Result;
    return ((int)r.StatusCode, r.Content.ReadAsStringAsync().Result);
}

// POST（フォーム＝[FromForm] のアクション。net10.0 の一部 Select 系）
static (int status, string body) PostForm(string url, string form)
{
    var content = new StringContent(form ?? "", System.Text.Encoding.UTF8, "application/x-www-form-urlencoded");
    HttpResponseMessage r = Http.PostAsync(url, content).Result;
    return ((int)r.StatusCode, r.Content.ReadAsStringAsync().Result);
}
```

## `DataTable` を受け取る／送る（DTTables 往復）

```csharp
using System.Data;
using Touryo.Infrastructure.Public.Dto;

// 一覧を取る：応答は {"suppliers":"<DTTables JSON 文字列>"}（camelCase・JSON in JSON）
static DataTable SelectAll()
{
    var (status, body) = PostJson(BaseUrl + "/api/batchupdate/SelectAll", "");
    if (status != 200) { return null; }

    string inner = ExtractJsonString(body, "suppliers");   // 内側の DTTables JSON を取り出す
    return inner == null ? null : FirstTable(DTTables.JsonToDTTables(inner));
}

// バッチ更新：DataTable → DTTables JSON を {"Suppliers":"<エスケープ>"} で包んで送る
static (int status, string body) BatchUpdate(DataTable dt)
{
    DTTables dtts = new DTTables();
    dtts.Add(DTTable.FromDataTable(dt, true));   // ★ keepOriginal:true＝往復後も Original が残る＝楽観排他が効く
    string json = DTTables.DTTablesToJson(dtts);
    return PostJson(BaseUrl + "/api/batchupdate/BatchUpdate", "{\"Suppliers\":" + JsonQuote(json) + "}");
}

static DataTable FirstTable(DTTables dtts)
{
    foreach (DTTable dtt in dtts) { return dtt.ToDataTable(); }
    return null;
}
```

## 楽観排他の確認（keepOriginal 往復が効くか）

```csharp
// ① 古い版を取る
DataTable stale = SelectAll();
int id = System.Convert.ToInt32(stale.Rows[0]["SupplierID"]);

// ② 別経路で同じ行を更新（他者の更新）
DataTable other = SelectAll();
FindById(other, id)["ContactTitle"] = "changed";
BatchUpdate(other);                       // → updateCount:1

// ③ 古い版を編集して送る → サーバが Original を WHERE に入れて件数0＝業務例外
FindById(stale, id)["ContactName"] = "stale-edit";
var (st, bd) = BatchUpdate(stale);
bool locked = st == 200 && System.Text.RegularExpressions.Regex.IsMatch(bd, "\"errorMessageID\"\\s*:\\s*\"W0002\"");
// locked == true なら楽観排他が成立している
```

## 判定と JSON ヘルパ

```csharp
// ★ 状態コード＋「形」で見る（部分一致は不可＝エラーページの HTML に語が混ざる）
static bool Ok(int status, string body, string pattern)
    => status == 200 && System.Text.RegularExpressions.Regex.IsMatch(body, pattern, System.Text.RegularExpressions.RegexOptions.IgnoreCase);
// 例：Ok(status, body, "\"count\"\\s*:\\s*\\d+") / 業務エラーは {"errorMessageID":..,"errorMessage":..,"errorInfo":..}

// 外側 JSON から文字列値を取り出す（camelCase/PascalCase 両対応・エスケープ復元）。
// JSON in JSON を扱うだけなのでライブラリ非依存の素朴実装でよい（サンプルに全文あり）。
static string ExtractJsonString(string json, string name) { /* "\"name\":\"…\"" を走査し \" \\ \n 等を復元 */ return null; }
// 文字列を JSON リテラルにエスケープする（" \ 制御文字）。
static string JsonQuote(string s) { /* サンプル参照 */ return "\"" + s + "\""; }

static DataRow FindById(DataTable dt, int id)
{
    foreach (DataRow dr in dt.Rows)
    {
        if (dr.RowState == DataRowState.Deleted) { continue; }
        if (System.Convert.ToInt32(dr["SupplierID"]) == id) { return dr; }
    }
    return null;
}
```

## 注意

- `ExtractJsonString`/`JsonQuote` の全文は `Frameworks\Tests\TestWebAPIClient\Program.cs`（サンプル）にある。DTO の往復が目的なら Newtonsoft/System.Text.Json を使ってもよい。
- Bearer トークンの取得（クライアント クレデンシャル／認可コード等）は `opentouryo-oauth2-client`。`SetBearer()` を呼んでから叩く。
- `DataTable` 往復の意味（`keepOriginal`・列属性は非保持・負値仮採番）は `opentouryo-batch-update`。サーバ側の返し方は `opentouryo-webapi-server`。
