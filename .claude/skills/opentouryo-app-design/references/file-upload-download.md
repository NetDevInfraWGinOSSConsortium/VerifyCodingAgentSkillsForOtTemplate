# ファイルのアップロード／ダウンロード（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。対象＝**P層**。
出典：OpenTouryo「ファイルのアップロード」「ファイルのダウンロード」（net48/classic の基本）＋**最新動向**（ASP.NET Core／セキュリティ。末尾の Sources）。

## アップロード

### net48（Web Forms・OpenTouryo サンプル）

- ブラウザ `<input type="file">`、サーバ `Request.Files["userfile"]`（`HttpPostedFile`）→ **`posted.SaveAs(保存先 + Path.GetFileName(posted.FileName))`**。UOC ハンドラ内（`opentouryo-layer-p-webforms-event`）。
- 制限：web.config `<httpRuntime maxRequestLength="4096"〔KB・既定 4MB〕 executionTimeout="90" requestLengthDiskThreshold=… />`、
  IIS `<requestLimits maxAllowedContentLength="…"〔bytes・既定約 28.6MB〕 />`。**両方**引っかかる。
- 注意：アップロード中はバッファ（メモリ/ディスク）に溜まる → **大容量はメモリ不足**。`Content-Length` で事前確認。大容量は WCF ストリーミング／分割。

### net10.0（ASP.NET Core）

- 小さいファイル：**`IFormFile`（バッファ）**。大きいファイル：**アンバッファのストリーミング**（`MultipartReader` / `Request.Body`）。
- 制限：`FormOptions.MultipartBodyLengthLimit` / `[RequestSizeLimit]` / `[RequestFormLimits]`、Kestrel `MaxRequestBodySize`、IIS `maxAllowedContentLength`。

### セキュリティ（アップロードの鉄則）

- **サイズを制限**する（メモリ枯渇攻撃対策）。
- **拡張子は許可リスト**＋Content-Type＋**マジックバイト（署名）で中身を検証**——拡張子・Content-Type は詐称できるので**信用しない**。
- **ファイル名はアプリが決める**（GUID 等）。**ユーザ提供のファイル名をそのまま使わない**（`../../web.config` 等の**パストラバーサル**）。表示/ログ時は**HTML エンコード**。
- **保存先は wwwroot の外**（できれば非システムドライブの専用領域）・**実行権限を外す**。
- **認証済みユーザのみ**許可（`opentouryo-auth`）。可能なら**ウイルススキャン**。

## ダウンロード

### net48（Web Forms）

`Response.Clear()` → ヘッダ設定 → 本体書き込み → 終了、の順。

- ヘッダ：`Content-Disposition: attachment; filename*=UTF-8''<percent>`（保存ダイアログ。`inline` は表示）、`Content-Type`（例 `application/pdf`）、キャッシュ制御（`Response.Cache.SetCacheability(NoCache)`＋`Pragma`）。
- 本体：小＝`Response.WriteFile` / `BinaryWrite`、**大容量＝`TransmitFile`（カーネルモード・メモリに載せない）or `Response.OutputStream.Write`**（KB812406）。
- `Response.End()` は `ThreadAbortException`／TCP 切断時の `HttpException: The remote host closed the connection` に注意（try/catch か `CompleteRequest`）。
- **日本語ファイル名**：ブラウザ差異あり → **RFC 6266/5987** の `filename*=UTF-8''<percent-encoded>`＋ASCII フォールバック `filename=`。

### net10.0（Core）

- **`File(...)` / `PhysicalFileResult` / `FileStreamResult` / `Results.File`** を使うと、Content-Disposition・**ファイル名エンコード**・Range（レジューム）・ETag を**フレームワークが処理**（手書きより安全）。`enableRangeProcessing: true` でレジューム。

### セキュリティ（ダウンロードの鉄則）

- **パストラバーサル**：ファイルパスを**ユーザ入力から直接組み立てない**。**ID→パスの対応表**にする／解決後のパスが許可ディレクトリ内かを検証。保存先は wwwroot 外。
- **任意ファイルダウンロード防止**：そのユーザがそのファイルを取得してよいかを**認可**する。
- **Content-Type は安全なマッピングから**（任意値を返さない）＋`X-Content-Type-Options: nosniff`。

## OpenTouryo との対応

- 実装は P層（`opentouryo-layer-p-webforms-event` / `opentouryo-layer-p-mvc`）。制限値は `opentouryo-config`（web.config）。認証・認可は `opentouryo-auth`。
- **※ OpenTouryo 公式サンプルは net48/classic**（`Request.Files` / `Response.WriteFile` / WCF ストリーミング）。**net10.0 では上記 Core の手段に置き換える**。

## Sources（最新動向）

- Microsoft Learn: Upload files in ASP.NET Core — https://learn.microsoft.com/en-us/aspnet/core/mvc/models/file-uploads
- Secure File Upload Handling in ASP.NET Core MVC — https://www.c-sharpcorner.com/article/secure-file-upload-handling-in-asp-net-core-mvc/
- File and Input Security in ASP.NET Core MVC/Web API — https://www.c-sharpcorner.com/article/file-and-input-security-in-asp-net-core-mvc-and-web-api-applicationsintroducti/
