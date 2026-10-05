import os
import UIKit
import UserNotifications
import UserNotificationsUI

@objc(NotificationViewController)
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim.NotificationContent", category: "NotificationViewController")

    private let card = UIView()
    private let iconView = UIImageView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let countdownLabel = UILabel()
    private let arcLayer = CAShapeLayer()
    private let sunView = UIImageView(image: UIImage(systemName: "sun.max.fill"))
    private var targetDate: Date?
    private var countdownTimer: Timer?

    #if DEBUG
    private let sentinelBanner = UILabel()
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        #if DEBUG
        Self.logger.notice("ZMANIM_NOTIFICATION_EXTENSION_VIEWDIDLOAD")
        #endif

        preferredContentSize = CGSize(width: 390, height: 235)
        view.semanticContentAttribute = .forceRightToLeft
        view.backgroundColor = UIColor(red: 0.972, green: 0.966, blue: 0.936, alpha: 1)

        #if DEBUG
        // Visually unmistakable background and sentinel banner in DEBUG
        sentinelBanner.translatesAutoresizingMaskIntoConstraints = false
        sentinelBanner.text = "ZMANIM CONTENT EXTENSION LOADED"
        sentinelBanner.font = .systemFont(ofSize: 13, weight: .heavy)
        sentinelBanner.textColor = .white
        sentinelBanner.backgroundColor = .systemIndigo
        sentinelBanner.textAlignment = .center
        sentinelBanner.layer.cornerRadius = 6
        sentinelBanner.clipsToBounds = true
        view.addSubview(sentinelBanner)
        #endif

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(red: 0.965, green: 0.945, blue: 0.885, alpha: 0.72)
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        view.addSubview(card)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .systemOrange
        iconView.contentMode = .scaleAspectFit

        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        eyebrowLabel.font = .preferredFont(forTextStyle: .caption1)
        eyebrowLabel.textColor = .secondaryLabel
        eyebrowLabel.textAlignment = .right
        eyebrowLabel.text = "תזכורת זמן"

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .right
        titleLabel.numberOfLines = 1

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        timeLabel.textAlignment = .right

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.font = .preferredFont(forTextStyle: .subheadline)
        countdownLabel.textColor = .secondaryLabel
        countdownLabel.textAlignment = .right

        let textStack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, timeLabel, countdownLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 3

        let header = UIStackView(arrangedSubviews: [textStack, iconView])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.axis = .horizontal
        header.alignment = .top
        header.spacing = 12
        header.semanticContentAttribute = .forceRightToLeft
        card.addSubview(header)

        let horizon = UIView()
        horizon.translatesAutoresizingMaskIntoConstraints = false
        horizon.backgroundColor = .clear
        card.addSubview(horizon)

        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.34).cgColor
        arcLayer.lineWidth = 2
        arcLayer.lineCap = .round
        horizon.layer.addSublayer(arcLayer)

        sunView.translatesAutoresizingMaskIntoConstraints = false
        sunView.tintColor = .systemOrange
        horizon.addSubview(sunView)

        var constraints = [
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            card.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42),
            horizon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            horizon.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            horizon.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            horizon.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            sunView.widthAnchor.constraint(equalToConstant: 22),
            sunView.heightAnchor.constraint(equalToConstant: 22),
            sunView.trailingAnchor.constraint(equalTo: horizon.trailingAnchor, constant: -6),
            sunView.bottomAnchor.constraint(equalTo: horizon.bottomAnchor, constant: -2)
        ]

        #if DEBUG
        constraints.append(contentsOf: [
            sentinelBanner.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            sentinelBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            sentinelBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            sentinelBanner.heightAnchor.constraint(equalToConstant: 18)
        ])
        #endif

        NSLayoutConstraint.activate(constraints)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let horizon = sunView.superview else { return }
        let rect = horizon.bounds.insetBy(dx: 8, dy: 4)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), controlPoint: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.25))
        arcLayer.path = path.cgPath
        arcLayer.frame = horizon.bounds
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content

        #if DEBUG
        let keys = content.userInfo.keys.map { String(describing: $0) }.sorted().joined(separator: ", ")
        Self.logger.notice("ZMANIM_NOTIFICATION_EXTENSION_DIDRECEIVE category=\(content.categoryIdentifier, privacy: .public) title=\(content.title, privacy: .public) userInfoKeys=[\(keys, privacy: .public)]")
        #endif

        titleLabel.text = content.userInfo["zmanTitle"] as? String ?? content.title
        iconView.image = UIImage(systemName: content.userInfo["zmanIcon"] as? String ?? "sunset.fill")

        if let seconds = content.userInfo["zmanTime"] as? Double {
            let target = Date(timeIntervalSince1970: seconds)
            targetDate = target
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "he_IL")
            formatter.dateFormat = "HH:mm"
            timeLabel.text = formatter.string(from: target)
            updateCountdown()
            countdownTimer?.invalidate()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                self?.updateCountdown()
            }
        } else {
            timeLabel.text = content.body
            countdownLabel.text = ""
        }
    }

    private func updateCountdown() {
        guard let targetDate else { return }
        let minutes = max(0, Int(ceil(targetDate.timeIntervalSinceNow / 60)))
        countdownLabel.text = minutes > 0 ? "בעוד \(minutes) דקות" : "הזמן הגיע"
    }

    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        #if DEBUG
        Self.logger.notice("ZMANIM_NOTIFICATION_EXTENSION_ACTION actionIdentifier=\(response.actionIdentifier, privacy: .public)")
        #endif

        switch response.actionIdentifier {
        case NotificationSchedulerConstants.snoozeActionID:
            let request = ZmanimSnoozeRequest.make(from: response.notification.request.content)
            UNUserNotificationCenter.current().add(request) { error in
                #if DEBUG
                if let error {
                    Self.logger.error("Failed to add snooze request: \(error.localizedDescription, privacy: .public)")
                } else {
                    Self.logger.notice("Snooze request added successfully: \(request.identifier, privacy: .public)")
                }
                #endif
                completion(.dismiss)
            }
        case NotificationSchedulerConstants.openActionID:
            completion(.dismissAndForwardAction)
        default:
            completion(.dismissAndForwardAction)
        }
    }

    deinit {
        countdownTimer?.invalidate()
    }
}
