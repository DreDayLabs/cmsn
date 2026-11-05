import SwiftUI

/// Not presented. Clothing feedback is off, so this screen has no copy.
/// The type stays in the app target; `ApparelFeedback` remains on the
/// local model for sessions that already stored one.
struct ApparelFeedbackView: View {
    var body: some View {
        Color.clear
            .accessibilityHidden(true)
    }
}
