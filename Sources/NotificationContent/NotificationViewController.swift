import os
import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private static let logger = Logger(subsystem: "com.davidpovarsky.Zmanim.NotificationContent", category: "NotificationViewController")

    private let card = UIView()
    private let iconView = UIImageView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let countdownLabel = UILabel()
    private let horizonView = UIView()
    private let arcLayer = CAShapeLayer()
    private let sunView = UIImageView(image: UIImage(systemName: "sun.max.fill"))

    private var targetDate: Date?
    private var countdownTimer: Timer?
    private var currentProgress: Double = 0.75

    #if DEBUG
    private let sentinelBanner = UILabel()
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        #if DEBUG
        Self.logger.notice("ZMANIM_NOTIFICATION_EXTENSION_VIEWDIDLOAD")
        #endif

        preferredContentSize = CGSize(width: 390, height: 240)
        view.semanticContentAttribute = .forceRightToLeft
        view.backgroundColor = UIColor(red: 0.972, green: 0.966, blue: 0.936, alpha: 1)

        #if DEBUG
        sentinelBanner.translatesAutoresizingMaskIntoConstraints = false
        sentinelBanner.text = "ZMANIM CONTENT EXTENSION LOADED"
        sentinelBanner.font = .systemFont(ofSize: 12, weight: .heavy)
        sentinelBanner.textColor = .white
        sentinelBanner.backgroundColor = .systemIndigo
        sentinelBanner.textAlignment = .center
        sentinelBanner.layer.cornerRadius = 6
        sentinelBanner.clipsToBounds = true
        view.addSubview(sentinelBanner)
        #endif

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(red: 0.965, green: 0.945, blue: 0.885, alpha: 0.85)
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(red: 0.105, green: 0.105, blue: 0.20, alpha: 0.10).cgColor
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
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .right
        titleLabel.numberOfLines = 1

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        timeLabel.textAlignment = .right

        countdownLabel.translatesAutoresizingMaskIntoConstraints = false
        countdownLabel.font = .preferredFont(forTextStyle: .subheadline)
        countdownLabel.textColor = UIColor.systemOrange
        countdownLabel.textAlignment = .right

        let textStack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, timeLabel, countdownLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 3

        let header = UIStackView(arrangedSubviews: [textStack, iconView])
        header.translatesAutoresizingMaskIntoConstraints = false
        header.axis = .horizontal
        header.alignment = .top
        header.spacing = 14
        header.semanticContentAttribute = .forceRightToLeft
        card.addSubview(header)

        horizonView.translatesAutoresizingMaskIntoConstraints = false
        horizonView.backgroundColor = .clear
        card.addSubview(horizonView)

        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.strokeColor = UIColor.systemOrange.withAlphaComponent(0.40).cgColor
        arcLayer.lineWidth = 2.5
        arcLayer.lineCap = .round
        horizonView.layer.addSublayer(arcLayer)

        sunView.translatesAutoresizingMaskIntoConstraints = false
        sunView.tintColor = .systemOrange
        sunView.contentMode = .scaleAspectFit
        horizonView.addSubview(sunView)

        var constraints = [
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            card.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            header.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),

            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40),

            horizonView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            horizonView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            horizonView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            horizonView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            horizonView.heightAnchor.constraint(equalToConstant: 36),

            sunView.widthAnchor.constraint(equalToConstant: 18),
            sunView.heightAnchor.constraint(equalToConstant: 18)
        ]

        #if DEBUG
        constraints.append(contentsOf: [
            sentinelBanner.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            sentinelBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            sentinelBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            sentinelBanner.heightAnchor.constraint(equalToConstant: 18)
        ])
        #endif

        NSLayoutConstraint.activate(constraints)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard horizonView.bounds.width > 0, horizonView.bounds.height > 0 else { return }

        let bounds = horizonView.bounds
        let margin: CGFloat = 12
        let base = bounds.height - 4
        let arcHeight = bounds.height - 10
        let p0 = CGPoint(x: margin, y: base)
        let p2 = CGPoint(x: bounds.width - margin, y: base)
        let p1 = CGPoint(x: bounds.width / 2, y: base - 2 * arcHeight)

        let path = UIBezierPath()
        path.move(to: p0)
        path.addQuadCurve(to: p2, controlPoint: p1)
        arcLayer.path = path.cgPath
        arcLayer.frame = bounds

        let t = CGFloat(currentProgress)
        let u = 1 - t
        let sunX = u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x
        let sunY = u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
        sunView.center = CGPoint(x: sunX, y: sunY)
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content

        #if DEBUG
        let keys = content.userInfo.keys.map { String(describing: $0) }.sorted().joined(separator: ", ")
        Self.logger.notice("ZMANIM_NOTIFICATION_EXTENSION_DIDRECEIVE category=\(content.categoryIdentifier, privacy: .public) title=\(content.title, privacy: .public) userInfoKeys=[\(keys, privacy: .public)]")
        #endif

        let title = content.userInfo["zmanTitle"] as? String ?? content.title
        titleLabel.text = title.isEmpty ? "תזכורת זמן" : title

        let iconName = content.userInfo["zmanIcon"] as? String ?? "sun.max.fill"
        iconView.image = UIImage(systemName: iconName) ?? UIImage(systemName: "sun.max.fill")

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
            timeLabel.text = content.body.isEmpty ? "--:--" : content.body
            countdownLabel.text = ""
        }

        if let progressVal = content.userInfo["zmanProgress"] as? Double {
            currentProgress = max(0, min(1, progressVal))
        } else if title.contains("שקיעה") {
            currentProgress = 0.90
        } else if title.contains("זריחה") {
            currentProgress = 0.10
        } else if title.contains("חצות") {
            currentProgress = 0.50
        } else {
            currentProgress = 0.75
        }

        view.setNeedsLayout()
    }

    private func updateCountdown() {
        guard let targetDate else { return }
        let minutes = Int(ceil(targetDate.timeIntervalSinceNow / 60))
        if minutes > 0 {
            countdownLabel.text = "בעוד \(minutes) דקות"
        } else if minutes == 0 {
            countdownLabel.text = "הזמן הגיע"
        } else {
            countdownLabel.text = "לפני \(abs(minutes)) דקות"
        }
    }

    func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        #if DEBUG
        Self.logger.notice("ZMANIM_NOTIFICATION_EXTENSION_ACTION actionIdentifier=\(response.actionIdentifier, privacy: .public)")
        #endif

        // Single-owner architecture: forward the action to NotificationCoordinator in the containing app
        completion(.dismissAndForwardAction)
    }

    deinit {
        countdownTimer?.invalidate()
    }
}
