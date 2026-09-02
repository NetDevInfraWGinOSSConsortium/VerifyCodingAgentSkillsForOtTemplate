# P層→B層 呼び出し コードスニペット（コピー元）

出典：UserGuide 開発者編 §4.2／各機能編 §6（通信制御）／リッチクライアント編 §4（2CS）、実ソースで裏取り。
**on-demand 参照**（SKILL 予算外）。

> ★ スニペット中の `TestParameterValue`／`TestReturnValue`／`LayerB`／`LayerD` は**配布サンプル由来の名前＝プレースホルダ**
> （`〈…〉` と同じく自プロジェクトの型名に読み替える。サンプルを消した状態からの実装ではこれらは実在しない）。

## インプロセス呼び出し（同一プロセスで B層を直接）

```csharp
protected string UOC_〈イベントハンドラ名〉(FxEventArgs fxEventArgs)
{
    // 引数クラスを生成
    TestParameterValue pv = new TestParameterValue(
        this.ContentPageFileNoEx,  // 画面を表す文字列（screenId）
        fxEventArgs.ButtonID,      // イベント発生元のコントロールID（controlId）
        "〈methodName〉",          // 呼び出す B層メソッド名（UOC_〈methodName〉 が呼ばれる）
        "〈actionType〉",          // 条件分岐等に使う自由文字列（先頭[0]=DBMS）
        this.UserInfo);            // ユーザ情報（ベース2 で追加した項目）

    // 分離レベル（一律 User＝MyFcBaseLogic.UOC_ConnectionOpen でプロジェクト既定へ振替）
    DbEnum.IsolationLevelEnum iso = DbEnum.IsolationLevelEnum.User;

    // B層を生成して実行
    LayerB myBusiness = new LayerB();
    TestReturnValue rv = (TestReturnValue)myBusiness.DoBusinessLogic(
        (BaseParameterValue)pv, iso);

    // 戻り値判定
    if (rv.ErrorFlag == true)
    {
        // 業務続行可能なエラー（B層が業務例外をスロー）
        string id  = rv.ErrorMessageID;
        string msg = rv.ErrorMessage;
        string inf = rv.ErrorInfo;
    }
    else
    {
        // 正常系
        var result = rv.Obj;
    }

    return "";  // URL を返すと画面遷移、空文字ならポストバック
}
```

## 通信制御経由（インプロセス⇄Webサービスをコード無変更で切替）

サービス論理名で呼ぶ。実体解決は `TMProtocolDefinition.xml`／`TMInProcessDefinition.xml`（`opentouryo-transmission`）。
**リモート（protocol=2〜5・実運用は 4/5＝2/3 は discon）は net48 専用**、net10.0 はインプロセスのみ。

```csharp
CallController cctrl = new CallController(this.UserInfo);
// 任意：プロキシ／WAS 認証情報（実行時はこちらが優先）
// cctrl.ProxyUrl = "http://proxy/";
// cctrl.NetworkCredentialToProxy = new NetworkCredential("id", "pw", "domain");

TestReturnValue rv = (TestReturnValue)cctrl.Invoke("〈サービス論理名〉", pv);
// 以降の ErrorFlag 判定は同上
```

## 3層構成（通信制御）での実装配置（後の物理分離に備える）

**共有契約（型）とサーバ実装（B/D）を別アセンブリに分ける。** これで client/server を後から物理分離できる。

| 実装物 | 3層（通信制御） | 2層（直呼び） |
| --- | --- | --- |
| 引数・戻り値クラス（**型情報**＝`MyParameterValue`/`MyReturnValue` 派生） | **型アセンブリ（共有）**＝client/server 両方が参照・`[Serializable]` | アプリ内 |
| **B層（`LayerB`）・D層（`LayerD`/Dao）** | **サーバ側アセンブリ** | アプリ内 |
| P層（呼び出し側） | 型を参照して `CallController.Invoke(論理名, pv)` | 型を参照して `new LayerB().DoBusinessLogic(pv, iso)` |

```csharp
// 【3層】P層（クライアント）：型は共有アセンブリを参照、呼び出しは通信制御
using WSIFType_sample;   // ← 引数・戻り値クラス（型情報）＝クライアントとサーバの共有契約
// ...
TestParameterValue pv = new TestParameterValue(/* screenId, controlId, methodName, actionType, */ this.UserInfo);
CallController cctrl = new CallController(this.UserInfo);
TestReturnValue rv = (TestReturnValue)cctrl.Invoke("〈サービス論理名〉", pv);
// → B層・D層はサーバ側アセンブリ（LayerB : MyFcBaseLogic、LayerD/Dao）に実装。
//   分離レベル・トランザクションはサーバ側で決める（iso=User 振替／TCDefinition／属性ベース）。

// ───────────────────────────────
// 【2層】P層：型も B/D もアプリ内（同一プロセスで直呼び）
using MyType;            // ← 引数・戻り値クラスはアプリ内
// ...
LayerB myBusiness = new LayerB();
TestReturnValue rv2 = (TestReturnValue)myBusiness.DoBusinessLogic((BaseParameterValue)pv, iso);
```

> 参考（配布サンプルの対応。**サンプルは 2層化・整理で削除されうるので、上のパターンを正とする**）：
> 3層＝`WS_sample/{WSIFType_sample＝型, WSServer_sample＝B/D}`＋`sampleScreen_cc.aspx.cs`／
> 2層＝`AppCode/.../{Common＝型, Business, Dao}`＋`sampleScreen.aspx.cs`。

## 2層C/S（リッチクライアント）＝手動トランザクション

C/S 2層では都度コミットせず手動制御する。B層は `MyFcBaseLogic2CS` を継承（`opentouryo-base2-customize`）。

```csharp
LayerB myBusiness = new LayerB();  // : MyFcBaseLogic2CS
TestReturnValue rv = (TestReturnValue)myBusiness.DoBusinessLogic(
    (BaseParameterValue)pv, DbEnum.IsolationLevelEnum.ReadCommitted);

// 終了処理（いずれか）
BaseLogic2CS.CommitAndClose();     // コミット＋切断
// BaseLogic2CS.RollbackAndClose(); // ロールバック＋切断
// BaseLogic2CS.ConnectionClose();  // NoTransaction 指定時（以降は自動コミット）は切断のみ
```

> ★ 業務例外はリスローされない（`ErrorFlag` で戻る）ので `catch` しない。詳細は `opentouryo-exception`。
> リッチクライアントで**非同期**に呼ぶなら `opentouryo-richclient-async`。
