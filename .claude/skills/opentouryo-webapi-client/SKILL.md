---
name: opentouryo-webapi-client
description: "OpenTouryo の Web API サーバ（OAuth2 リソースサーバ＝opentouryo-webapi-server）を .NET クライアント（net48／Core・コンソール/バッチ/別サービス）から呼ぶ。HTTP で api/<controller>/<action> を叩く（疎通は GET /test、業務は POST）。本文は基本 application/json、サーバが [FromForm] のアクションは x-www-form-urlencoded で送る。認証は Authorization: Bearer <token>（取得は opentouryo-oauth2-client。None 許可のサーバはトークン無しでも通る）。DataTable は DTTables JSON で往復＝応答 {\"suppliers\":\"<DTTables JSON>\"} の内側文字列を JsonToDTTables(json).ToDataTable()、送信は FromDataTable(dt, keepOriginal:true)→DTTablesToJson を {\"Suppliers\":\"<エスケープ>\"} で包む。keepOriginal で往復後も RowState と Original が残り、サーバの全列 Original 楽観排他（他者更新で件数0＝errorMessageID W0002）が成立。判定は本文の部分一致でなく状態コード＋形（正規表現）、4xx/5xx も本文を読む、業務エラーは { errorMessageID, errorMessage, errorInfo }。WebAPI 呼び出し / REST クライアント / Bearer 付き HTTP / DataTable を JSON で受け取る / API 疎通確認 に使う。サーバは opentouryo-webapi-server、通信制御（CallController.Invoke）は別物で opentouryo-transmission、DTTables は opentouryo-batch-update。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# Web API クライアント（OpenTouryo リソースサーバを叩く）

**OpenTouryo の Web API サーバ（`opentouryo-webapi-server`）を .NET から呼ぶ**型。クライアントは net48／Core のコンソール・バッチ・別サービス等。
Bearer トークンの取得（IdP 連携）は `opentouryo-oauth2-client`、`DataTable` の JSON 往復は `opentouryo-batch-update`／`opentouryo-common-parts`。

> 📋 **コピー元スニペット（HTTP 呼び出し・DTTables 往復・楽観排他の流れ）は `references/snippets.md`。** サーバ側は `opentouryo-webapi-server`。

> **★ 通信制御（`opentouryo-transmission` の `CallController.Invoke`）とは別物。** あれはサービス論理名で WCF/net.tcp を解決する仕組み。
> こちらは **素の HTTP＋JSON**（`HttpClient`／`HttpWebRequest` で `api/<controller>/<action>` を直接叩く）。

## 呼び出し

- **エンドポイント**：`http(s)://<host>/api/<controller>/<action>`。**疎通は `GET .../test`**（DB を使わない）、業務は **`POST`**。
- **本文の型はサーバに合わせる**：基本は **`application/json`**（`[FromBody]` の DTO）。**サーバが `[FromForm]` のアクション（一覧・件数など）は `application/x-www-form-urlencoded`** で送る
  （例 `ddlDap=SQL&ddlMode1=individual&…`）。net10.0 の一部 Select 系は `[FromForm]`＝合わせないと 415/モデル空になる。
- **認証＝`Authorization: Bearer <token>` ヘッダ**。トークンは IdP から取得する（`opentouryo-oauth2-client`）。**サーバが `EnumHttpAuthHeader.None` を許す構成（疎通テスト等）ならトークン無しでも通る**が、実運用のリソースサーバは Bearer 必須。
- **応答は 4xx/5xx でも本文を読む**（例外にして捨てない＝原因が分からなくなる）。

## `DataTable` を受け取る／送る（DTTables JSON）

サーバは `DataTable` を **DTTables JSON を「JSON の中の文字列」として** 返す（camelCase）：`{ "suppliers": "<DTTables JSON 文字列>" }`。

```csharp
// 受け取る：外側 JSON から内側の文字列を取り出す → DataTable へ
string inner = ExtractJsonString(res.Body, "suppliers");   // "{...DTTables JSON...}"
DataTable dt = DTTables.JsonToDTTables(inner).ToDataTable();   // RowState と Original が戻る

// 送る：DataTable → DTTables JSON を {"Suppliers":"<エスケープした JSON>"} で包む
DTTables dtts = new DTTables(); dtts.Add(DTTable.FromDataTable(dt, keepOriginal: true));
string body = "{\"Suppliers\":" + JsonQuote(DTTables.DTTablesToJson(dtts)) + "}";
```

- **★ `keepOriginal: true` で送る。** 往復後も `RowState`（Added/Modified/Deleted）と**変更前値 `Original`** が残り、サーバ側の**全列 `Original` 楽観排他が成立**する（詳細は `opentouryo-batch-update`）。
- **楽観排他の確認**：一覧を取る→別経路で同じ行を更新→古い版を編集して送る＝**サーバが更新件数0で業務例外**（応答に `errorMessageID: "W0002"` 等）。これが返れば排他が効いている。

## 応答の判定（部分一致で判定しない）

- **状態コード＋「形」で見る。** 本文に語が含まれるかだけで判定すると、**エラーページの HTML に語が混ざって誤判定**する（実例：IIS Express の 500.19 の HTML に `test` が入り疎通 OK に見えた）。
  `res.Status == 200 && Regex.IsMatch(body, "\"count\"\\s*:\\s*\\d+")` のように**状態コードと正規表現**で見る。
- **業務エラーの形**：`{ errorMessageID, errorMessage, errorInfo }`（サーバが camelCase で返す）。`ErrorFlag` 相当はこの有無で判断する。

## やってはいけないこと

- **`CallController.Invoke`（通信制御）でこの REST API を呼ぼうとする** — 別機構。HTTP クライアントで直接叩く（`opentouryo-transmission` は WCF/net.tcp 用）。
- **`[FromForm]` のアクションに JSON を送る／`[FromBody]` にフォームを送る** — サーバの受け方に合わせる。
- **`DataTable` を素の JSON でやり取りする** — `RowState`/変更前値が落ちる。`DTTables` を使う（送信は `keepOriginal:true`）。
- **本文の部分一致だけで合否判定する** — 状態コード＋形で見る。4xx/5xx も本文を読む。
- **Bearer トークンをコードに直書きする** — IdP から取得する（`opentouryo-oauth2-client`）。
