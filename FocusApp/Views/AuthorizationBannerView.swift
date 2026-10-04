import SwiftUI
import FamilyControls
import UIKit

struct AuthorizationBannerView: View {
    @EnvironmentObject private var store: FocusStore

    var body: some View {
        if store.authorizationStatus != .approved {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(Color.orange)

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.authorizationStatus == .denied ? "Screen Time 权限被拒绝" : "需要 Screen Time 权限")
                        .font(.subheadline.weight(.semibold))

                    Text("授权后才能使用白名单拦截功能。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if store.authorizationStatus == .denied {
                        Button("打开设置") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                        .font(.footnote.weight(.semibold))
                    } else {
                        Button("授权") {
                            Task {
                                await store.requestAuthorization()
                            }
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
