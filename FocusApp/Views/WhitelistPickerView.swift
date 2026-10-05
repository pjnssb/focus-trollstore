import SwiftUI
import FamilyControls

struct WhitelistPickerView: View {
    @Binding var selection: FamilyActivitySelection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(
                headerText: "选择专注期间允许使用的 App",
                footerText: "重要：请把「专注」和「TrollStore」也加入白名单，否则它们会被盾牌拦住。",
                selection: $selection
            )
            .navigationTitle("选择白名单 App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
