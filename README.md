# 概要
- Open棟梁向けに開発されたコーディング・エージェントのスキルを実験・検証するためのリポジトリのテンプレート
- フォークしたり、ZIPでクローンしたりして使用すると良い。使用時は前提部を当該環境で書き換えること。
- 検証用リポジトリは `New-VerifyRepo.ps1` で作れる（例 `./New-VerifyRepo.ps1 -Clone`。リポジトリ名（既定 `VerifyCa*ForOT`）・公開か非公開か・組織を対話で聞き、最後に GO / NOGO を聞く。`-WhatIf` を付けると何をするかだけを表示する。作った後に行うことは実行の最後に表示される）。

## 前提
- CodingAgentは、xxxx（モデルはxxxx）
- .NETは、net48、netxx.x が前提
- [Open棟梁](https://github.com/OpenTouryoProject/OpenTouryo)はxx-xxを使用...既定はdevelop(.dosc/prompt/検証プロンプト.md）
- [OpenTouryoCodingAgentAssets](https://github.com/OpenTouryoProject/OpenTouryoCodingAgentAssets)から最新スキル（xx-xx）をインストール。
- [LocalServicesOnDocker](https://github.com/NetDevInfraWGinOSSConsortium/LocalServicesOnDocker)でDB（ローカル・サービス）を動かしておく。

## プロンプト
docのplan、specを参照するので以下の非常に短いプロンプトのみで検証可能。

- .\docs\prompt\検証プロンプト.md の セットアップ > 基本 の Core、Transformを実行して下さい。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の マスタ の 1-5 を実行して下さい。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の トランザクション1 の 1-5 を実行して下さい。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の トランザクション2 の 1-5 を実行して下さい。  
モジュール名等に使用するProgramIDには受注管理のprefix:Ordを使用して下さい（例:OrdListSearch、OrdBusiness）。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の トランザクション3 の 1-5 を実行して下さい。  
トランザクション3 は トランザクション2 に明細を追加実装するもので、同じProgramIDを使用します（例:OrdDetailedView）。