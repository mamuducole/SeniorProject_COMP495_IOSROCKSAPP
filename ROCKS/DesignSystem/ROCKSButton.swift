import SwiftUI

struct ROCKSButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(ROCKSColor.gold)
        .foregroundStyle(ROCKSColor.black)
    }
}
