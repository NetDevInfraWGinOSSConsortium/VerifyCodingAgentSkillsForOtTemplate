---
name: opentouryo-transmission
description: "OpenTouryo の通信制御機能を実装する。CallController.Invoke / InvokeAsync にサービス論理名を渡して B層を呼び出し、インプロセス呼び出しと Web サービス呼び出しを定義ファイルだけで切り替える仕組みを扱う。TMProtocolDefinition.xml（protocol / url / url_ref / timeout / prop_ref / Url / Prop）と TMInProcessDefinition.xml（assemblyName / className）の書式、ProtocolNameService / InProcessNameService による名前解決を扱う。リモート呼び出し（protocol=2〜5＝2 ASP.NET SOAP・3 WCF basicHttpBinding〔2/3 は discon〕・4 WCF netTcpBinding・5 ASP.NET WebAPI）は BinarySerialize のドロップにより net48 専用で、net10.0（core）ではインプロセス（protocol=1）しか動かない点も扱う。通信制御 / サービス論理名 / CallController / インプロセス呼び出し / Web サービス呼び出し / 分散呼び出し / TMProtocolDefinition / TMInProcessDefinition を伴う作業のときに使う。他の XML 定義ファイルは opentouryo-message / opentouryo-shared-property / opentouryo-screen-transition / opentouryo-transaction-control を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 通信制御機能

> 📋 **コピー元スニペット**：`references/snippets.md`（CallController.Invoke・TMProtocol/TMInProcess 定義・net48限定注意。実装時はここから写す）。

## このスキルの適用範囲

サービス論理名による B層の呼び出しと、それを支える2つの定義ファイル
（`TMProtocolDefinition.xml` / `TMInProcessDefinition.xml`）。

**この2ファイルで1つの機能。** 片方だけでは成立しない。

他の XML 定義ファイルは機能ごとに別スキルへ分かれている（`opentouryo-message` /
`opentouryo-shared-property` / `opentouryo-screen-transition` /
`opentouryo-transaction-control`）。

**この2ファイルも他の XML 定義ファイルと共通の作法に従う。** DTD を埋め込み、`id` は XML の
`ID` 型なので先頭に数字を使えず、パスは `appSettings` の `Fx` キー
（`FxXMLTMProtocolDefinition` / `FxXMLTMInProcessDefinition`）で指定する。
**ランタイムによらず XML のまま。**

## 何のための機能か

**「サービス論理名」を渡すだけで B層を呼べるようにする。** 呼び出し先が同一プロセス内なのか
Web サービス越しなのかを、**呼び出し側のコードから隠す**。

```csharp
// P層から
CallController cctrl = new CallController(this.UserInfo);
TestReturnValue rv = (TestReturnValue)cctrl.Invoke("testWebService", parameterValue);
```

`Invoke("testWebService", ...)` の解決は**2段**。**インプロセスか否かで引く定義が分かれ、リモートは「クライアントとサーバの両方」を引く**（実ソースで裏取り＝`CallController.cs`／`FxController.cs`／`WCFTCPSvcForFx.cs`）。

```
① クライアント：TMProtocolDefinition で protocol を引く（★ protocol 解決はクライアント側だけ）

  protocol="1"（インプロセス）
    → クライアント：TMInProcessDefinition で assemblyName/className を引き、同一プロセスで直接呼ぶ
       ★ サーバ側の定義は一切通らない
  protocol="2"〜"5"（リモート。2=ASP.NET SOAP・3=WCF basicHttpBinding〔2/3 は discon〕・4=WCF netTcpBinding・5=ASP.NET WebAPI）
    → クライアント：TMProtocolDefinition の url/timeout/props で転送する
    → サーバ（ServiceInterface）：TMInProcessDefinition で assemblyName/className を引き B層を呼ぶ
       ★ クライアントの TMInProcessDefinition は通らない／サーバは TMProtocolDefinition を持たない
```

**同じ論理名のまま、定義ファイルを直すだけでインプロセス⇄リモートを切り替えられる。** これがこの機能の目的。

**★ `TMInProcessDefinition.xml` は「クライアント」と「サーバ」の2箇所にある**（同名・別物）。**リモートでも使うサービス論理名は、両方に同じ `id` を登録する**
（クライアント側＝`protocol="1"` 用・プロジェクト直下の相対パス／サーバ側＝リモート用・`%OT_RESOURCE_ROOT%\Xml\`）。所在と設定キーの**非対称表は `references/snippets.md`**。

`Invoke` の非同期版として `InvokeAsync(serviceName, parameterValue)` もある。

**★ `Invoke`/`InvokeAsync` は `(serviceName, parameterValue)` の2引数のみ＝分離レベル（`iso`）を渡せない（設計）。**
3層C/S ではサーバとクライアントが分離するので、**分離レベルはサーバ側の関心事**。CallController／WS の入口は B層を常に
`iso=User` で呼び（`CallController.cs` L366・`FxController.cs`・`WCFTCPSvcForFx.cs`）、実際の分離レベルはサーバ側で決める
（親クラス2 の `User` 振替／属性ベースで B層に埋め込む）。Web でインプロセスかつ per-call で分離レベルを変えたいなら、
`Invoke` でなく `new LayerB().DoBusinessLogic(pv, iso)` 直呼び（`opentouryo-p-call-business`「呼び出し経路の選択」）。

### リモート呼び出し（`protocol="2"`〜`"5"`）は net48 専用

**`net10.0`（core）では、インプロセス（`protocol="1"`）しか動かない。** リモート（`protocol="2"`〜`"5"`）は**net48 のみ**。
**`protocol` の値**（`FxEnum.TmProtocol`。実ソース）：**`1`=インプロセス／`2`=ASP.NET SOAP〔ASMX〕／`3`=WCF basicHttpBinding／`4`=WCF netTcpBinding／`5`=ASP.NET WebAPI。`2`・`3` は discon（廃止）＝実運用は `1` と `4`/`5`。**

理由：リモート呼び出しは `.NET` オブジェクトのバイナリ シリアライズ（`BinarySerialize`）で
引数・戻り値を転送するが、**`BinarySerialize` は core でドロップされた**（`opentouryo-common-parts`）。
`CallController` は core でもビルドされるが、リモート系プロトコルは**未実装**＝core で `protocol="2"`〜`"5"` を渡すと **`FrameworkException` を投げる**（#543。以前は `null` を返していた＝原因に辿れなかったので是正された。`CallController.cs`）。

core で物理3層が必要なら、別の通信手段（REST / gRPC など）を独自に実装する。

**サンプル/ランタイム選択への含意：`Samples4NetCore\Legacy\WS_sample\WSClient_sample\`（.NET Core 版の
WS クライアント）は、この制約により実質インプロセス呼び出ししか動かず、実用的な物理3層にならない
（起点として勧めない）。3層リッチクライアントを実用するなら net48 側**（`Samples\WS_sample\WSClient_sample\`）
**を選ぶ**（新規立ち上げのサンプル選択は `opentouryo-project-setup-selection` ①表を参照）。

## TMInProcessDefinition.xml（インプロセス呼び出しの名前解決）

**サービス論理名から、呼び出すアセンブリとクラスを解決する。** 定義例は `references/snippets.md`。属性：

| 属性 | 内容 |
| --- | --- |
| `id` | サービス論理名 |
| `assemblyName` | アセンブリ名 |
| `className` | クラス名（名前空間を含む完全名） |

**★ サービス論理名は「呼び先の B層クラス」に対応する（→ 固定エントリ `DoBusinessLogic` を呼ぶ。実ソース `CallController.cs`・`TRANSMISSION_INPROCESS_METHOD_NAME="DoBusinessLogic"`）。実際の業務メソッド（`UOC_<名>`）は `pv.MethodName` で選ぶ＝サービス論理名では選ばない**（`opentouryo-p-call-business`）。
∴ **呼び先の B層クラスが同じなら、サービス論理名の追加は不要＝既存の論理名を再利用する**（メソッドごとに論理名を増やさない。**B層相乗り**のケースでは既存の論理名を共通で使える）。**新規に論理名が要るのは、呼び先クラス（`assemblyName`/`className`）が変わるとき、または経路（`protocol`）を変えるとき**だけ。

**サービス論理名から、呼び出すプロトコルと URL を解決する。** 定義例は `references/snippets.md`。属性：

| 属性 | 内容 |
| --- | --- |
| `protocol` | **`1`=インプロセス／`2`=ASP.NET SOAP／`3`=WCF basicHttpBinding／`4`=WCF netTcpBinding／`5`=ASP.NET WebAPI**（`2`・`3` は discon＝実運用は `1`/`4`/`5`） |
| `url` / `url_ref` | URL を直接指定するか、`Url` 要素を参照する（`IDREF`） |
| `prop_ref` | `Prop` 要素を参照する（`IDREF`） |
| `timeout` | タイムアウト |

**`Url` / `Prop` をマスタとして定義し、`Transmission` から `url_ref` / `prop_ref` で参照する**
構造。同じ URL を複数のサービスで使う場合に重複を避けられる。

### Prop はプロパティ文字列

`Prop` の `value` には **`名前=値;` を並べた文字列**を書く。

```xml
<Prop id="prop_a" value="aaa=AAA;bbb=BBB;ccc=CCC;"/>
<Transmission id="testWebService" protocol="5" url_ref="url_c" prop_ref="prop_a"/>   <!-- 5=WebAPI（live）。2/3 は discon -->

```

フレームワークがこれを `Dictionary<string, string>` に展開して呼び出し側へ渡す
（`ProtocolNameService.NameResolutionProtocolUrl(name, out url, out timeout, out props)`）。

`prop_ref` で参照した `Prop` に `value` 属性が無いと `FrameworkException` になる。

## リモート（3層）で漏らしやすいこと（実測＋実ソースで裏取り）

- **★ サービス論理名を足すなら**（＝呼び先の B層クラスや経路が**新規**のとき。同一クラスなら追加不要＝上記の再利用）、**クライアントとサーバの両方の `TMInProcessDefinition.xml` に登録する。** リモート経路は**サーバ側**を引く（`FxController`／`WCFTCPSvcForFx`＝`ServiceInterface`）ので、クライアント側だけ直しても通らない（＝`Transmissionタグに合致するid属性値がありません`）。
- **★ 経路（`TMProtocolDefinition`）×実体（`TMInProcessDefinition`）を、使う protocol の数だけ 1対1 で作る。** `protocol="4"`（WCF netTcp）と `"5"`（Web API）は**別々に登録が要る**（片方だけだとその経路は存在しない）。サービス論理名は経路ごとに分けるのが分かりやすい（例 `…WCFTcp`＝4／`…WebAPI`＝5／`…InProcess`＝1）。
- **★ `TMProtocolDefinition` はクライアントに2ファイルある（`.xml` と `2.xml`）＝両方に入れる。** `app.config` が実際に参照するのは片方だが、**config の切替でもう片方に移ると経路が消える**（実測：`2.xml` にだけ入れて `.xml` が空＝切替で解決不能）。
- **★ `protocol="1"`（インプロセス）の疎通は、3層（リモート）の疎通を保証しない。** protocol=1 は**サーバ側定義を一切通らない**ため、緑でもリモート経路は1行も検証されていない＝**必ず `protocol="4"`/`"5"` でも1回叩く**。さらに**インプロセスへの暗黙フォールバックでないこと**を、**ホスト（`WCFService`/`ASPNETWebService`）を落とすと 4/5 は失敗し 1 だけ成功する**ことで裏取りする。
- **★ 定義ファイルは `static` にキャッシュされ、編集しても再読込されない**（名前解決サービス `PRT_NS`/`IPR_NS` は `CallController`／`FxController`／`WCFTCPSvcForFx` で `static`＝アプリドメイン起動時に1回だけ読む。実ソース）。編集後は**リサイクル必須**——サーバ＝`iisreset`／アプリプール リサイクル／`Web.config` の更新（IIS Express は `taskkill /IM iisexpress.exe` で落として再起動）、クライアント＝プロセス再起動。
- **所在の非対称表・新サービス追加チェックリスト・エラー→切り分け表は `references/snippets.md`。**

## やってはいけないこと

- **`CallController.Invoke()` に呼び出し先の URL やクラス名を渡す** — 渡すのはサービス論理名。
  実体の解決は定義ファイルが行う
- **`TMProtocolDefinition` だけ書いて `TMInProcessDefinition` を書かない** — 2ファイルで
  1つの機能。**`protocol="1"` はクライアント側の、`"2"`/`"4"`/`"5"`（リモート）はサーバ側の** `TMInProcessDefinition` が要る
- **クライアント側の定義だけ直してリモート経路が通ると考える** — リモートは**サーバ側**の `TMInProcessDefinition` を引く（`ServiceInterface`）。両方に同じ `id` を登録する
- **`protocol="1"` の疎通確認だけで3層を検証済みとする** — サーバ側定義を通らない。`protocol="4"`/`"5"` でも1回叩く
- **定義ファイルを編集してサーバ／クライアントを再起動せずに試す** — `static` キャッシュ＝リサイクル（サーバ）／プロセス再起動（クライアント）まで反映されない
- **`id` の先頭に数字を使う** — XML の `ID` 型なので不正
- **`prop_ref` で参照する `Prop` に `value` 属性を書かない** — `FrameworkException` になる
- **呼び出し側のコードでインプロセスか Web サービスかを分岐する** — 隠すのがこの機能の目的。
  切り替えは定義ファイルで行う
- **`net10.0`（core）でリモート呼び出し（`protocol="2"`〜`"5"`）を使う** — 未実装で `Invoke` が
  `FrameworkException` を投げる（#543）。core で使えるのはインプロセス（`protocol="1"`）だけ
