# 前提
- .NETは、net48、netxx.x が前提
- Open棟梁はxx-xxを使用（2026/8）
- 使用したCodingAgentは、xxxx（モデルはxxxx）
- LocalServicesOnDockerでDB（ローカル・サービス）を動かしておく。

# 入力したプロンプト
docのplan、specを参照するので以下の非常に短いプロンプトのみで検証可能。

- .\docs\prompt\検証プロンプト.md の セットアップ > 基本 の Core、Transformを実行して下さい。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の マスタ の 1-5 を実行して下さい。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の トランザクション1 の 1-5 を実行して下さい。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の トランザクション2 の 1-5 を実行して下さい。  
モジュール名等に使用するProgramIDには受注管理のprefix:Ordを使用して下さい（例:OrdListSearch、OrdBusiness）。

- .\docs\prompt\検証プロンプト.md の アプリ実装 の トランザクション3 の 1-5 を実行して下さい。  
トランザクション3 は トランザクション2 に明細を追加実装するもので、同じProgramIDを使用します（例:OrdDetailedView）。