import Foundation
import Testing

extension Trait where Self == ConditionTrait {
    /// For tests that activate the test process or put windows in front of other apps, taking the focus of whoever is
    /// using the Mac. They run with LAMINA_UI_TESTS=1 (`make test-ui`, and CI, where nobody is at the keyboard).
    static var showsWindows: Self {
        .enabled(if: ProcessInfo.processInfo.environment["LAMINA_UI_TESTS"] == "1",
                 "takes focus or shows windows; set LAMINA_UI_TESTS=1 (make test-ui) to run it")
    }
}
