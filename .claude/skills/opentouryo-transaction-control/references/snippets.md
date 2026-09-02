# トランザクション制御 コードスニペット（コピー元）

出典：UserGuide 各機能編 §5、`Framework/Business/BaseLogic.cs`・`TransactionControl.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## パターンで Dam を初期化

```csharp
// Dam 生成 → パターンIDで初期化 → フレームワーク管理下へ
BaseDam damWork = new DamSqlSvr();
BaseLogic.InitDam("SQL_RC", damWork);   // TCDefinition.xml の SQL_RC（connkey＋isolevel）で初期化
this.SetDam(damWork);
```

## トランザクショングループで複数 Dam

```csharp
string[] patterns;
BaseLogic.GetTransactionPatterns("SQLSvr", out patterns);
foreach (string pattern in patterns)
{
    BaseDam damWork = new DamSqlSvr();
    BaseLogic.InitDam(pattern, damWork);
    this.SetDam(pattern, damWork);   // キー付きで管理下へ
}
```

## XML 定義（TCDefinition.xml）

`isolevel`：`nc`(接続しない)/`nt`(ノーTx)/`uc`(ReadUncommitted)/`rc`(ReadCommitted)/`rr`(RepeatableRead)/`sz`(Serializable)/`ss`(Snapshot)/`df`(Default)。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE TCD[
 <!ELEMENT TCD (TransactionPattern*, TransactionGroup*)>
 <!ELEMENT TransactionPattern EMPTY><!ELEMENT TransactionGroup EMPTY>
 <!ATTLIST TransactionPattern id ID #REQUIRED connkey CDATA #IMPLIED
   isolevel (nc|nt|uc|rc|rr|sz|ss|df) "rc">
 <!ATTLIST TransactionGroup id ID #REQUIRED value CDATA #REQUIRED>
]>
<TCD>
  <TransactionPattern id="SQL_RC" connkey="ConnectionString_SQL" isolevel="rc"/>
  <TransactionPattern id="SQL_SZ" connkey="ConnectionString_SQL" isolevel="sz"/>
  <TransactionGroup id="SQLSvr" value="SQL_RC,SQL_SZ"/>
</TCD>
```

config パス：`<add key="FxXMLTCDefinition" value="...\TCDefinition.xml"/>`。

## 属性ベース（サービス化時に業務クラスへパターンを付与）

```csharp
[MyAttribute(TransactionPatternID = "SQL_RC")]
public class LayerB : MyBaseLogic
{
    public MyAttribute GetAttr() => MyAttribute.GetCustomAttributes(this);
}
```

> B層の分離レベル指定（`DoBusinessLogic(pv, iso)`。一律 `DbEnum.IsolationLevelEnum.User` を渡す）は `opentouryo-layer-b` / `-p-call-business`。

## 高度なトランザクション操作（★ 非標準・逸脱は要相談）

既定は自動コミット／例外時のみロールバック。以下は標準外なので例外認可を個別検討（`opentouryo-project-policy`）。

```csharp
// ── 分割コミット（B層で途中コミットして続行）──────────────
this.GetDam().CommitTransaction();          // ここまでを確定
this.GetDam().BeginTransaction(DbEnum.IsolationLevelEnum.ReadCommitted); // 続きを開始
```

```csharp
// ── SAVEPOINT（プロバイダ固有。例：Oracle）────────────────
// Oracle Dam（ODP.NET は DamManagedOdp、旧 OracleClient は DamOraClient）が
// DamOracleTransaction（OracleTransaction）を公開する
OracleTransaction tx = ((DamManagedOdp)this.GetDam()).DamOracleTransaction;
tx.Save("MySavePoint");                      // セーブポイント作成
// … 途中でやり直したくなったら …
tx.Rollback("MySavePoint");                  // セーブポイントまでロールバック
```

- **手動トランザクション制御**：**B層なら `this.GetDam()`（フレームワーク管理下の Dam）を取得して
  `BeginTransaction`/`CommitTransaction`/`RollbackTransaction` を自分で呼べば手動制御できる**（新規に Dam を生成する必要はない）。
  **例外時の扱い（認可）は個別に決める。**
- **2本目以降の接続は「キー付き Dam」で管理下に追加**（標準・上の「トランザクション グループで複数 Dam」節）：
  サーバ側 `BaseLogic` は `SetDam(key, dam)`/`GetDam(key)` と `_dams`（`Dictionary<string,BaseDam>`）で複数 Dam を保持し、
  **全 Dam を一括コミット／ロールバック**する。★ **2CS `BaseLogic2CS` はキー付き `SetDam` を持たず単一 `static _dam` のみ**（`InitDam(パターン, dam)`
  で追加接続は開けるが、コミット／クローズは手動＝`CommitAndClose` は `_dam` だけ）。FAQ「2CS も2本目可能」はこの手動運用を指す。
- **2フェーズコミット（分散 Tx）は未サポート**。`TransactionScope` 対応の親クラス1 を作らない限り使えない。
