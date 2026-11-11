import SwiftUI
import UIKit
import UserNotifications
import UserNotificationsUI

public final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var hosted: UIHostingController<NotificationSolarView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 390, height: 265)
        view.backgroundColor = UIColor(red: 0.972, green: 0.966, blue: 0.936, alpha: 1)
    }

    public func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        let title = content.userInfo["zmanTitle"] as? String ?? content.title
        let icon = content.userInfo["zmanIcon"] as? String ?? "sun.max.fill"
        let target = (content.userInfo["zmanTime"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue)
        }
        let sunrise = (content.userInfo["sunriseTime"] as? NSNumber).flatMap {
            $0.doubleValue > 0 ? Date(timeIntervalSince1970: $0.doubleValue) : nil
        }
        let sunset = (content.userInfo["sunsetTime"] as? NSNumber).flatMap {
            $0.doubleValue > 0 ? Date(timeIntervalSince1970: $0.doubleValue) : nil
        }
        let city = content.userInfo["cityName"] as? String ?? ""
        let sky = NotificationSkyState.load().flatMap { candidate -> NotificationSkyState? in
            guard let latitude = (content.userInfo["latitude"] as? NSNumber)?.doubleValue,
                  let longitude = (content.userInfo["longitude"] as? NSNumber)?.doubleValue else {
                return nil
            }
            return abs(candidate.latitude - latitude) < 0.04
                && abs(candidate.longitude - longitude) < 0.04 ? candidate : nil
        }
        let solar = NotificationSolarView(title: title, icon: icon, target: target,
                                          sunrise: sunrise, sunset: sunset,
                                          city: city, sky: sky,
                                          notificationID: notification.request.identifier)
        hosted?.willMove(toParent: nil)
        hosted?.view.removeFromSuperview()
        hosted?.removeFromParent()
        let host = UIHostingController(rootView: solar)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hosted = host
    }

    public func didReceive(
        _ response: UNNotificationResponse,
        completionHandler completion: @escaping (UNNotificationContentExtensionResponseOption) -> Void
    ) {
        completion(.dismissAndForwardAction)
    }
}