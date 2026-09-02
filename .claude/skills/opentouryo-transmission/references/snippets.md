# 通信制御 コードスニペット（コピー元）

出典：UserGuide 各機能編 §6、`Framework/Transmission/*`・`CallController`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## サービス論理名で呼び出し（インプロセス⇄WebService をコード無変更で切替）

```csharp
CallController cctrl = new CallController(this.UserInfo);
// 任意オプション（実行時はこちらが優先）
// cctrl.ProxyUrl = "http://proxy/";
// cctrl.NetworkCredentialToProxy = new NetworkCredential("id","pw","domain");
// cctrl.NetworkCredentialToWAS   = new NetworkCredential("id","pw","domain");

TestReturnValue rv = (TestReturnValue)cctrl.Invoke("〈サービス論理名〉", pv);
// ErrorFlag 判定は opentouryo-p-call-business と同じ
```

> ★ リモート（protocol=`2`〜`5`）は **net48 専用**。net10.0 はインプロセス（protocol=`1`）のみ
> （`BinarySerialize` が core に無い＝core は `2`〜`5` で `FrameworkException` を投げる。`CallController.cs`）。

## 呼び出し先の名前解決（TMProtocolDefinition.xml）＝クライアント側のみ

**`protocol`**（`FxEnum.TmProtocol`・実ソース）：`1`=インプロセス／`2`=ASP.NET SOAP〔ASMX〕／`3`=WCF basicHttpBinding／`4`=WCF netTcpBinding／`5`=ASP.NET WebAPI。
**`2`・`3` は discon（廃止）＝実運用は `1`（インプロセス）と `4`/`5`（リモート）。** `4`/`5` は配布 `TMProtocolDefinition.xml` に既定で含まれる。

```xml
<TMD>
  <Transmission id="testInProcess" protocol="1"/>
  <Transmission id="testRemote"    protocol="5" url="https://xxx/WebAPIControllerForFx" timeout="60"/>   <!-- 5=WebAPI（live）。2/3 は discon -->
</TMD>
```

## 呼び出しモジュールの名前解決（TMInProcessDefinition.xml）

```xml
<TMD>
  <Transmission id="testInProcess" assemblyName="WSServer_sample"
    className="WSServer_sample.Business.LayerB" />
</TMD>
```

```xml
<add key="FxXMLTMProtocolDefinition"  value="...\TMProtocolDefinition.xml"/>
<add key="FxXMLTMInProcessDefinition" value="...\TMInProcessDefinition.xml"/>
```

## ★ 定義ファイルの所在は「クライアント」と「サーバ」で非対称（同名だが別物・別配置）

`TMInProcessDefinition.xml` は**クライアントとサーバの2箇所にあり、同名なので「片方に足した＝完了」と錯覚する**。リモートでも使う `id` は**両方に登録**する。

| | クライアント（呼び出し側） | サーバ（`ServiceInterface`＝呼ばれる側） |
| --- | --- | --- |
| `FxXMLTMProtocolDefinition`（`TMProtocolDefinition.xml`） | **あり**（プロジェクト直下の相対パス）＝protocol/url/props を解決 | **無し**（protocol 解決はクライアントの関心事＝ホスト `app.config` に該当キー無し） |
| `FxXMLTMInProcessDefinition`（`TMInProcessDefinition.xml`） | **あり**（同上）＝**`protocol="1"` 用** | **あり**（`%OT_RESOURCE_ROOT%\Xml\`）＝**リモート〔`protocol="2"`〜`"5"`〕用** |

- `protocol="1"`（インプロセス）＝クライアントの2ファイルだけ引く（サーバ側は通らない）。
- リモート（`2`〜`5`。実運用は `4`/`5`＝`2`/`3` は discon）＝クライアントは `TMProtocolDefinition` で転送先を決め、**サーバが自分の `TMInProcessDefinition` で `assemblyName`/`className` を解決**（`FxController.cs`／`WCFTCPSvcForFx.cs`＝`static IPR_NS.NameResolution`）。

## ★ 新しいサービス論理名を足すときのチェックリスト

- **インプロセスだけ使う** → クライアント側の `TMProtocolDefinition`（`protocol="1"`）＋`TMInProcessDefinition` の2ファイルに追加。
- **リモートも使う** → 上記に加えて**サーバ側 `%OT_RESOURCE_ROOT%\Xml\TMInProcessDefinition.xml` にも同じ `id` を追加**（ホストが複数〔`ASPNETWebService`/`WCFService`〕なら全ホストが同じファイルを見ているか実測）。
- 追加後は**リサイクル**（サーバ）／**プロセス再起動**（クライアント）＝下記。**必ず `protocol="4"`/`"5"` でも1回叩く**（`protocol="1"` はサーバ側を通らず3層を検証できない）。

## ★ 定義は static キャッシュ＝編集後はリサイクル必須

名前解決サービスは `static`（`CallController` の `PRT_NS`/`IPR_NS`・`FxController`/`WCFTCPSvcForFx` の `IPR_NS`）で、`InProcessNameService` はコンストラクタで XML を**1回だけ**読む（実ソース）。編集しても再読込されない：

- **サーバ**：`iisreset`／アプリプール リサイクル／`Web.config` の更新日時を更新（IIS Express は `taskkill /IM iisexpress.exe` で落として再起動）。ホスト `app.config` 自身にも「パラメータ変更後は iisreset」と注記がある。
- **クライアント**：プロセス再起動。

## ★ エラー → 切り分け

| 症状 | 原因 |
| --- | --- |
| `Transmissionタグに合致するid属性値（X）がありません`（SERVICE-IF ログ＝`FxController` 由来） | **サーバ側**の `TMInProcessDefinition.xml` に未登録、または編集後にリサイクルしていない |
| 同エラーが**クライアント**のスタックから | クライアント側の `TMInProcessDefinition.xml` に未登録（`protocol="1"` のとき） |
| `FrameworkException`（Fx パスの記述誤り＝`ERROR_IN_WRITING_OF_FX_PATH2`）が**全**サービス名で発生 | `%OT_RESOURCE_ROOT%` が未解決／古い（`InProcessNameService` の生成時に例外）。個別の `id` だけ失敗するなら環境変数は原因ではない |

## サーバ側（サービスインターフェイス）

テンプレートは `Frameworks/Infrastructure/ServiceInterface/ASPNETWebService`（`FxController`）／WCF（`WCFTCPSvcForFx`）。
コンテキスト/引数の .NET オブジェクト化とサーバ側認証を実装する。3層 WS 構成の配置は `opentouryo-project-setup-core`（`samples/webservices.md`）。
