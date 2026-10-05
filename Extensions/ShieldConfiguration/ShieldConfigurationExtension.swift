import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        remember(application)
        return makeApplicationConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        remember(application)
        return makeApplicationConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeWebConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeWebConfiguration()
    }

    private func remember(_ application: Application) {
        guard let token = application.token else { return }
        SharedDefaults.save(token, forKey: SharedDefaults.lastShieldedApplicationTokenKey)
    }

    private func makeApplicationConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.92),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: "你在干什么啦╰_╯", color: .label),
            subtitle: ShieldConfiguration.Label(text: "快点学习去啦", color: .secondaryLabel),
            primaryButtonLabel: ShieldConfiguration.Label(text: "本 App 用 5 分钟", color: .white),
            primaryButtonBackgroundColor: .systemBlue
        )
    }

    private func makeWebConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor.systemBackground.withAlphaComponent(0.92),
            icon: UIImage(systemName: "hourglass"),
            title: ShieldConfiguration.Label(text: "你在干什么啦╰_╯", color: .label),
            subtitle: ShieldConfiguration.Label(text: "快点学习去啦", color: .secondaryLabel)
        )
    }
}
