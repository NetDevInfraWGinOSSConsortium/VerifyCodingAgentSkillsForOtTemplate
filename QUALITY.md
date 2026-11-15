# 品質の羅針盤（QUALITY.md）

<!-- OpenTouryoCodingAgentAssets の src/compass/QUALITY.sample.md から、src/compass/INSTALL.md 2 の手順で埋めた（OpenTouryoCodingAgentAssets#21。2026-11-15）。
     このリポジトリが持つ（入れ直しでも上書きしない）。テンプレートから作った検証リポジトリは、この内容から始まる。 -->

**どこを・何で・どれだけ確かめるか**を、このリポジトリについて決めた文書。人が決め、エージェントが従う。

- **共通の決まりは [`QUALITY.common.md`](QUALITY.common.md)**（配布物。直さない）。**節の番号は同じ**で、本書には各節のこのリポジトリの中身だけを書く
- **エージェントは、変更の前に本書と `QUALITY.common.md` を読む**（[`AGENTS.md`](AGENTS.md) から参照し、`CLAUDE.md` から読み込んでいる）

> **人は個々の変更を細かく見るより、羅針盤を決める役を担う。**
> エージェントは、作業が品質マップのどの単位に当たるかを本書で引き、その重みで確かめ、報告する。

## このリポジトリの値

`QUALITY.common.md` の「このリポジトリの値」は、この表を指す。

| 項目 | 値 |
|---|---|
| 検出器の置き場所 | `tools/ExpectationGuard` |
| 判定の用例の置き場所 | `tools/ExpectationGuard/ExpectationGuard.Tests` |
| 入れ直しのコマンド | `<アセット>\install\install.ps1 -Product claude -TargetRoot <このリポジトリ> -IncludeQualityGuard` |
| 宛先のブランチ（段 3 で検査する PR の宛先） | `develop`・`master`・`main`（`.github/workflows/expectation-change.yml`） |
| 必須のチェック | `expectation-change`（検証リポジトリを作った後に、人がブランチ保護で必須にする。まだなら、そう書き換える） |
| 共有の作業ブランチ | 無し（`main` に直接。共有のブランチを作ったら書き足す） |
| 変更のレビュー役（4 節） | `opentouryo-change-reviewer` |
| テスト先行のレビュー役 | `opentouryo-test-reviewer`（[`TESTING.md`](TESTING.md) 5） |
| 回帰テストの名前 | テストのケース名（テスト仕様の 1 行）に、根拠として Issue の番号を書く |

### 一次情報

**本書には方針と表だけを置く。** 手順は各文書が一次情報である。

| 内容 | 一次情報 |
|---|---|
| テスト先行の進め方・テストの保護 | [`TESTING.md`](TESTING.md)、[`docs/spec/cmn-testfirst.md`](docs/spec/cmn-testfirst.md)、[`docs/plan/cmn-testfirst.md`](docs/plan/cmn-testfirst.md) |
| 検証の手順（何をどの順で作るか） | [`docs/prompt/検証プロンプト.md`](docs/prompt/検証プロンプト.md)、[`docs/plan/`](docs/plan/) |
| 仕様（根拠の ID の出典） | NorthwindDbSampleSpec（<https://github.com/OpenTouryoProject/NorthwindDbSampleSpec>）の `HLD/Common.md`・`LLD/TableSchema`・`LLD/UI_ElementsAndEventList`・`LLD/EventSpec`・決定記録 `LLD/Decisions`。フレームワークごとの画面の決まりは [`docs/spec/cmn-framework.md`](docs/spec/cmn-framework.md) |
| レビューの観点（テスト先行） | [`docs/plan/cmn-testfirst-review.md`](docs/plan/cmn-testfirst-review.md) |

---

## 1. 品質マップ

**単位**：層（P層・B層・D層）と、すべての画面に効く共通の部分。DB は SQL Server。

| 単位 | リスク | 正の根拠 | 検証の手段 | 人が必ず見る箇所 |
|---|---|---|---|---|
| B層の業務ロジック（業務コードクラスの `UOC_*`。`DoBusinessLogic` が入口で、トランザクションの境界。マスタ・受注のバッチ更新を含む） | **高** | EventSpec・TableSchema の業務ルール・決定記録（`EV-*`・`VAL-*`・`ERR-*`・`DEC-*`） | B層の単体テスト（NUnit。`opentouryo-test-layer-b`） | 業務エラーの判定（`ErrorFlag`・メッセージ ID）、更新の件数と範囲、トランザクションの範囲と分離レベル |
| すべての画面に効く共通の部分（共通のレイアウト `_Layout.cshtml`・Master Page、設定 `app.config`・`appsettings.json`、画面遷移・メッセージの定義） | **中〜高** | `docs/spec/cmn-framework.md`、`HLD/Common.md` | 疎通（既存の画面を開く）、画面の E2E | 共通のレイアウト・設定の既定値・接続文字列の変更、**親クラス 1・2 を直していないか**（[`AGENTS.md`](AGENTS.md)「クラスの階層と修正可否」） |
| D層（CmnDao で実行する SQL・CLI で自動生成した Dao） | **中〜高** | TableSchema、SQL Server の文法 | B層の単体テスト（DB の状態まで見る） | SQL の組み立て（パラメタ化）、自動生成の Dao を手で直していないか、検索の条件とページの範囲 |
| P層の画面（WebForms・MVC・WinForms・WPF の画面コード、メッセージ・ダイアログ、ページング、グリッドの編集） | 中 | UI_ElementsAndEventList・EventSpec、`docs/spec/cmn-framework.md` | Web は画面の E2E（`opentouryo-test-e2e-web`）、Windows は人の確認 | 入力の検証（`VAL-*`）、更新の前の YES/NO の確認、エラーの表示（`ERR-*`）、状態を変える要求の CSRF 対策（Web） |
| テストの補助・ツール・スクリプト（`tools/`・`New-VerifyRepo.ps1` など） | 低 | — | 動かして確かめる | 原則として見ない（検出器の写しは直さない。`QUALITY.common.md` 3 節） |

- **テストのデータは、テストが自分で入れて消す。** Northwind の元の行を書き換える変更は、報告の冒頭に書く（`docs/spec/cmn-testfirst.md`）
- OpenTouryo の版（`OpenTouryoAssemblies`）を変えるときは、作った画面のテストをすべて通す

---

## 2. 正の定義

- **根拠**：仕様の ID（`EV-*`・`SC-*`・`*-T*`・`VAL-*`・`ERR-*`）か、決定記録の ID（`DEC-*`）。**仕様に無い期待値は書かない**（`docs/spec/cmn-testfirst.md`）
- **観測の扱い**：**使わない。** 根拠の ID を付けられないケースは、仕様の決定として人に上げ、決まるまでケースを作らない（[`TESTING.md`](TESTING.md) 2・5）
- **外部の基準**：無し（静的解析などは入れていない）

---

## 3. 期待値の変更と、その承認

- **期待値の変更に当たるもの**：[`TESTING.md`](TESTING.md) 3 と、検出器の `tools/ExpectationGuard/rules.psd1`
  （`<Webプロジェクト名>.Tests/`・`<Webプロジェクト名>.E2ETests/` の下の `.cs` で、テストの削除・`Ignore` の追加・`[Basis(` の削除・`Assert.`・`Expect(` の削除）
- 仕様が変わってテストを変えるときは、トレーラーに変わった仕様の ID と仕様の版を書く（`TESTING.md` 4）

---

## 4. レビューの観点

**単位に応じて、次を確かめる。** どの単位でも見る観点は `QUALITY.common.md` 4 節、テスト先行のテスト仕様・テスト・実装の観点は [`docs/plan/cmn-testfirst-review.md`](docs/plan/cmn-testfirst-review.md) にある。

### B層（業務ロジック）

- [ ] 業務エラーは `BusinessApplicationException` で返しているか（`ErrorFlag = true` に変わる。呼び出し側で `catch` していないか）
- [ ] バッチ更新で、更新の件数・対象の範囲（検索の結果セットに限る）が仕様のとおりか
- [ ] トランザクションの範囲（2CS の手動トランザクションを含む）と分離レベルが、`opentouryo-transaction-control` の決まりに合うか

### DB（D層）

- [ ] パラメタ化できる値を、パラメタにしているか。リテラル・識別子を文字列で組み立てていないか
- [ ] 自動生成の Dao を手で直していないか（直すなら生成し直す）
- [ ] 読んだ値で書き戻していないか（並行した要求の更新が消える）

### Web のセキュリティ（P層の Web と、共通の部分）

- [ ] 状態を変える要求で、CSRF の対策（MVC の `ValidateAntiForgeryToken` など）を外していないか
- [ ] リダイレクトの行き先に、利用者の入力が素通しで入らないか（オープン リダイレクト）
- [ ] 例外の画面・ログに、利用者に見せてはいけない内容（スタック トレース・接続文字列）を出していないか
- [ ] net48 と net10.0 で振る舞いが分かれないか（同じ画面を両方で作るとき）

---

## 5. フィードバックの輪

- `QUALITY.common.md` 5 節のとおり。テスト先行の検証で見つかった観点は、[`docs/plan/cmn-testfirst-review.md`](docs/plan/cmn-testfirst-review.md) にも戻す

---

## 6. 計測

- **テスト先行の検証ごとに**：仕様の取りこぼし・手戻り・人に上げた仕様の決定の数（今の検証（いきなり実装）と比べる。羅針盤の「アプリ開発への展開」）
- **B層のテストの根拠の種類の内訳**（`EV-*`・`VAL-*`・`ERR-*`・`DEC-*`・Issue）。基準の値は、まだ取っていない

---

## 7. 期待値の根拠の書き方

- **書き方**：テスト仕様（`docs/spec/<名前>-tests.md`）の「根拠」の列に ID を書き、テストのメソッドに `[Basis("<ID>")]` を付ける（[`TESTING.md`](TESTING.md) 2・3）

```csharp
[Test]
[Basis("EV-ORD-102")]
[Basis("VAL-ORD-01")]
public void OrdTfSearch_顧客で絞る() { ... }
```

---

## 8. エージェント向けチェックリスト

共通の項目は `QUALITY.common.md` 8 節。このリポジトリでは、次も確かめる。

- [ ] テスト仕様の先頭に、起こした仕様の版を書いたか。仕様の更新に追随したなら、版を書き換えたか（`TESTING.md` 2・4）
- [ ] テストのデータを、テスト自身が入れて消しているか（Northwind の元の行を書き換えていないか）
