# 期待値の変更の検出器の、リポジトリごとの規則（rules.psd1）の見本（OpenTouryoCodingAgentAssets#3）。
#   install.ps1 -IncludeQualityGuard は、導入先に rules.psd1 が無いときだけ、これを rules.psd1 として置く（以後は導入先が持つ）。
#   共通の規則（rules.common.psd1）に、配列は足され、値は上書きされる。
#
#   書き方
#     - パスは git のパス（リポジトリのルートから。区切りは /）に当てる正規表現。
#     - 配列は、要素が 1 つでも @( ) で書く。
#     - psd1 にはスクリプトを書けない。固有の比べ方（正規化など）は、Comparer にスクリプトのパスを書いて差し込む。
#   rules.psd1 自体も仕組みのファイルなので、変えたコミットにはトレーラー Expectation-Change が要る。
@{
    # 導入の印。-Range は、このパスが木に無いコミット（導入より前）を見ない。省略時は本体の場所。
    #   入口を別に残す（本体を別の場所に置き、元のパスに呼び出しだけを残す）ときは、元のパスを書く。
    # IntroducedBy = 'tools/ExpectationGuard/CheckExpectationChange.ps1'

    # 行の差し引きで読む diff の範囲（git の pathspec。ルートから）。省略時はリポジトリ全体。
    # DiffScope = @('src/')

    # 表示に添える、期待値の変更の定義の参照（例 'QUALITY.md 3 節'）。省略可。
    # Reference = 'QUALITY.md 3 節'

    # 仕組みのファイルに足すもの（比較のスクリプトなど）
    Guard = @(
        # '^tools/CompareResult\.ps1$'
    )

    # ------------------------------------------------------------------
    # 行の差し引き（ファイルごと）
    # ------------------------------------------------------------------
    #   Count = Removed … 当たる行が、足した数より多く消えたら検出（テストの削除・検証の削除）
    #   Count = Added   … 当たる行が、消した数より多く足されたら検出（Skip・Ignore の追加）
    #   Match の要素に Paths を書くと、そのパスのファイルでだけ当てる（1 行は、規則ごとに 1 回だけ数える）。
    #   属性の並び（[Test, Ignore("...")]）にも当たるよう、[ か , の直後を見る。
    LineRules = @(
        # アプリ開発の既定（OpenTouryoCodingAgentAssets#4）：テストは NUnit、テストのプロジェクトは <Webプロジェクト名>.Tests/
        #   （スキル opentouryo-test-layer-b・TESTING.md 3 節）。別の置き場所なら Paths を合わせる。
        @{
            Name  = 'テストの削除'
            Paths = @('^(.+/)?[^/]+\.Tests/.+\.cs$')
            Count = 'Removed'
            Match = @(
                @{ Pattern = '[\[,]\s*(Test|TestCase|TestCaseSource)\s*[\],(]' }
            )
        }
        @{
            Name  = 'Ignore の追加'
            Paths = @('^(.+/)?[^/]+\.Tests/.+\.cs$')
            Count = 'Added'
            Match = @(
                @{ Pattern = '[\[,]\s*(Ignore|Explicit)\s*[\],(]|\bAssert\s*\.\s*Ignore\s*\(' }
            )
        }
        @{
            Name  = '根拠の削除'
            Paths = @('^(.+/)?[^/]+\.Tests/.+\.cs$')
            Count = 'Removed'
            Match = @(
                @{ Pattern = '[\[,]\s*Basis\s*\(' }
            )
        }
        @{
            Name  = '検証の削除'
            Paths = @('^(.+/)?[^/]+\.Tests/.+\.cs$')
            Count = 'Removed'
            Match = @(
                @{ Pattern = '\bAssert\s*\.' }
            )
        }
    )

    # ------------------------------------------------------------------
    # ファイル単位の期待値（Golden など）
    # ------------------------------------------------------------------
    #   追加・削除は、それだけで期待値の変更。変更は、Comparer があればそれで比べ、無ければ差分があれば期待値の変更。
    #   Comparer（ルートからのパス）の呼び方 : & <Comparer> -Pairs <Path・Expected・Actual の並び>
    #     Expected・Actual は、変更の前・後の内容を書いた一時ファイル。
    #     返すもの : 対ごとに Path・Changed（真偽）・Detail（表示の補足。省略可）のオブジェクト
    #   CommandPattern は段 1 で、コマンドがこのファイルを書き換えそうかを見る。
    FileRules = @(
        # @{
        #     Name           = 'Golden'
        #     Paths          = @('^tests/Golden/.+/Result[^/]*\.txt$')
        #     Comparer       = 'tools/CompareGolden.ps1'
        #     CommandPattern = 'Golden'
        # }
    )

    # ------------------------------------------------------------------
    # 呼び出しの引数を、コミット全体でキーごとに比べる（根拠の変更など）
    # ------------------------------------------------------------------
    #   Call(…) の KeyIndex 番目の引数をキー、ValueIndex 番目を値とし、変わった・消えたキーを検出する。
    #   ファイルをまたいで移しただけなら数えない。引数は文字列の外の空白を除いて比べる（折り返しは数えない）。
    KeyedArgumentRules = @(
        # @{
        #     Paths       = @('^tests/.+\.cs$')
        #     Call        = 'Report'
        #     KeyIndex    = 0
        #     ValueIndex  = 3
        #     MinArgs     = 4
        #     RemovedName = '根拠の削除'
        #     ChangedName = '根拠の変更'
        # }
    )

    # ------------------------------------------------------------------
    # トレーラーの検査
    # ------------------------------------------------------------------
    #   値の最初の語が Vocabulary に無ければ止める（終了コード 1）。
    #   RequiredWhen（メッセージに当てる正規表現）に当たるのにトレーラーが無ければ、警告に留める。
    #   Found-By（OpenTouryoCodingAgentAssets#5）は共通の規則にある。同じ Name で書くと置き換える。
    TrailerRules = @(
        # @{
        #     Name         = 'Spec-Id'
        #     RequiredWhen = '(?i)\bfixed\s+#\d+'
        #     MissingHint  = '仕様の ID（EV-*・VAL-* など）を書く。'
        # }
    )

    # ------------------------------------------------------------------
    # 生成物の作り直しの漏れ（-Range -CheckGenerated）
    # ------------------------------------------------------------------
    #   Sources のファイルで、Items に当たる内容（出てくる順）が変わったのに、Generated が変わっていなければ検出する。
    #   ExemptTrailer が範囲のコミットのどれかにあれば通す。
    #   Items の Take : All（引数をすべて）・First（最初の引数）・Name（name グループ）。label グループがあれば Label より優先。
    GeneratedRules = @(
        # @{
        #     Name           = 'TESTCASES.md'
        #     Generated      = 'tests/TESTCASES.md'
        #     Sources        = @('^tests/E2E/.+\.cs$')
        #     Items          = @(
        #         @{ Pattern = '(?<![\w])Report\s*\('; Take = 'All'; Label = 'Report' }
        #         @{ Pattern = '\.\s*(?<label>Step|Verify)\s*\('; Take = 'First' }
        #         @{ Pattern = 'public\s+(?:async\s+)?(?:Task|void)\s+(?<name>\w+)\s*\('; Take = 'Name'; Label = 'test' }
        #     )
        #     ExemptTrailer  = 'TestCases-Unchanged'
        #     Hint           = @('テストを回して TESTCASES.md を作り直してください。')
        #     CommandPattern = 'TESTCASES\.md'
        # }
    )
}
