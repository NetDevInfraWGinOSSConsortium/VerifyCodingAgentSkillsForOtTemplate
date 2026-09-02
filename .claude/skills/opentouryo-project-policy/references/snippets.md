# プロジェクト方針の確認 コードスニペット（読む側の見どころ）

出典：UserGuide 共通編/纏め者編、`Frameworks/Infrastructure/Business/**`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。
このスキルは**読んで確認する側**（書かない）。以下は「親クラス2 ソースを読むとき、何がどう書かれているか」の見本。

## 見どころ：ソース中でこう書かれている（探す目印）

```csharp
// ── DBMS 選択 / 接続文字列（Business/MyFcBaseLogic.cs の UOC_ConnectionOpen）──
switch (parameterValue.ActionType.Split('%')[0]) { case "SQL": ... }   // ★ ActionType は PascalCase
connstring = GetConfigParameter.GetConnectionString("ConnectionString_SQL");
// 対応 Dam は #if でランタイム別（OLE/ODB/ODP=net48、NPS=core）
// ※ 2CS 構成なら RichClient/Business/MyFcBaseLogic2CS.cs を読む（同名メソッド）

// ── User 分離レベルの振替先（同 UOC_ConnectionOpen）──
if (iso == DbEnum.IsolationLevelEnum.User) { iso = DbEnum.IsolationLevelEnum.ReadCommitted; } // ← 振替先を確認

// ── %1/%2 置換（Presentation/MyBaseController.cs の UOC_ABEND。Web Forms のみ実装のことが多い）──
message.Replace("%1", ...).Replace("%2", ...);

// ── MyUserInfo の項目（Util/MyUserInfo.cs）＝プロパティ一覧を見る（既定は UserName / IPAddress）──

// ── 追加された接頭辞（Util/MyLiteral.cs）＝ PREFIX_OF_* 定数（既定は CheckBox のみ追加）──

// ── 事前定義の例外メッセージ（Exceptions/MyBusiness*ExceptionMessage.cs）＝ string[]{ id, msg } 定数──
```

読む対象の所在（`base2-overlay/` → 展開ツリー `Temp/` or `C:\otr\...` → 無ければ上流 `archive/<ref>.zip`）と
`<ref>` 復元は SKILL 本文（`build-ref.txt`／フォルダ名／纏め者に確認）。overlay に無い＝未改変＝既定値が仕様。

## ③ 纏め者への質問テンプレート（コピーして使う）

```markdown
## プロジェクトの方針を確認させてください
以下が判断できないため、実装を止めています。（（）内は既定テンプレートの値）

### 親クラス2 の実装について（ソースが参照できないため）
1. `MyUserInfo` に追加している項目はありますか。（既定: UserName / IPAddress の2つ）
2. 業務例外メッセージの `%1`/`%2` 置換は行っていますか。（既定: Web Forms の MyBaseController のみ）
3. `IsolationLevelEnum.User` はどの分離レベルへ振り替えていますか。（既定: ReadCommitted）
4. `UOC_ABEND` で例外を振り替えていますか。条件と振替先は。（既定: 雛形のみ・一般例外はリスロー）

### 運用ルールについて（コードから読めないため）
5. `OPERATION` ログの書式（項目と区切り）は。（ACCESS/SQLTRACE はカンマ区切り）
6. イベントログ（CustomEventLog / SecurityEventLog）はどういう場面で出しますか。
```

> 聞くのはその作業に必要な項目だけ。確定した事実は `PROJECT-POLICY.md`（コミット・全エージェント可視）へ記録。
> 親クラス2 を**変える**のは纏め者＝`opentouryo-base2-customize`（このスキルは読むだけ）。
