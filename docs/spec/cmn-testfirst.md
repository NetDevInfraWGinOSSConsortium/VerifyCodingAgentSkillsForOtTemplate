# 基本的な処理の内容
画面の機能を、**テスト先行**（`TESTING.md`）で実装する。いきなり実装しない。
作る範囲は、対象ごとの仕様（例 [受注一覧 OrdTf](./test3-testfirst-OrdTf.md)）に書く。本書は、どの対象にも共通の決まりを書く。

## 仕様の出どころ（段 0 で読む）
NorthwindDbSampleSpec（<https://github.com/OpenTouryoProject/NorthwindDbSampleSpec>）。

- 本文：`HLD/Common.md`（`PRE-*`・`VAL-*`・`ERR-*`）、`LLD/TableSchema`・`LLD/UI_ElementsAndEventList`・`LLD/EventSpec` の対象のモジュール
- **決定記録：`LLD/Decisions`**。本文は意図的に不完全なまま保たれていて、決まったことはここにある。**本文と合わせて読む**（食い違うときは決定記録が正）

## 役
- **司令役**：最初に指示を受けるセッション。手順は [plan/cmn-testfirst.md](../plan/cmn-testfirst.md)。
- **実装役**：サブ エージェント `opentouryo-test-implementer`（`.claude/agents`。Copilot は `.github/agents`）。
- **レビュー役**：サブ エージェント `opentouryo-test-reviewer`（`.claude/agents`。Copilot は `.github/agents`）。実装役とは別のモデル。
- **人**：仕様の決定だけを GO/NOGO で判断する（`TESTING.md` 5）。

## 決まり
- テストケースの根拠の ID は、仕様の ID（`EV-*`・`SC-*`・`*-T*`・`VAL-*`・`ERR-*`）か、決定記録の ID（`DEC-*`）。**仕様に無い期待値は書かない**（仕様の決定として人に上げる）。
- テストのデータは、テストが自分で入れて消す（テスト用の顧客などを作り、その行だけで確かめる）。Northwind の元の行は書き換えない。
- B層のテストに加えて、画面の振る舞い（ボタンの活性・移動・条件を保つ・表示）は画面の E2E のテストで確かめる（Web のとき）。
- テスト仕様・計画・決定のレポートの名前は、対象の仕様に書く。
