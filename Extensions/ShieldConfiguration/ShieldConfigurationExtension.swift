import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeApplicationConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeApplicationConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeWebConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeWebConfiguration()
    }

    private func makeApplicationConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.92),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: "你在干什么啦╰_╯", color: .label),
            subtitle: ShieldConfiguration.Label(text: "快点学习去啦", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "临时使用 5 分钟", color: .white),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "结束专注", color: .systemRed)
        )
    }

    private func makeWebConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.92),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: "你在干什么啦╰_╯", color: .label),
            subtitle: ShieldConfiguration.Label(text: "快点学习去啦", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "结束专注", color: .white),
            primaryButtonBackgroundColor: .systemRed
        )
    }
}
