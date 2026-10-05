import Combine
import CoreLocation
import Foundation
import WidgetKit
@MainActor final class AppModel:ObservableObject {
 @Published var cityName="מאתר מיקום…";@Published var timeZone=TimeZone.current;@Published var todayItems:[ZmanItem]=[];@Published var allItems:[ZmanItem]=[];@Published var settings=AppGroupStore.loadSettings();@Published var isLoading=false;@Published var errorMessage:String?
 let locationService=LocationService();private var currentLocation:CLLocation?
 init(){NotificationCoordinator.shared.install();locationService.onLocation={[weak self] location in Task{@MainActor in await self?.load(location:location)}}}
 func start(){if settings.locationMode == .fixed && !settings.fixedCity.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty{Task{await refreshFixedCity()}}else{locationService.start()}}
 func refresh(){if settings.locationMode == .fixed{Task{await refreshFixedCity()}}else{locationService.refresh()}}
 func refreshFixedCity() async {let q=settings.fixedCity.trimmingCharacters(in:.whitespacesAndNewlines);guard !q.isEmpty else{errorMessage="הקלד עיר קבועה או בחר במיקום הנוכחי.";return};do{let r=try await locationService.resolve(city:q);await load(location:r.location,preferredCity:r.city,preferredTimeZone:r.timeZone,force:true)}catch{errorMessage="לא הצלחנו למצוא את העיר שבחרת."}}
 func load(location:CLLocation,preferredCity:String?=nil,preferredTimeZone:TimeZone?=nil,force:Bool=false) async {if !force,let currentLocation,currentLocation.distance(from:location)<100,!todayItems.isEmpty{return};isLoading=true;defer{isLoading=false};let d=await locationService.describe(location);let city=preferredCity ?? d.city,zone=preferredTimeZone ?? d.timeZone;do{let items=try await HebcalService.fetchDays(location:location,timeZone:zone,count:8);cityName=city;timeZone=zone;allItems=items;currentLocation=location;var cal=Calendar(identifier:.gregorian);cal.timeZone=zone;todayItems=items.filter{cal.isDate($0.date,inSameDayAs:Date())};AppGroupStore.saveSnapshot(.init(cityName:city,timeZoneID:zone.identifier,latitude:location.coordinate.latitude,longitude:location.coordinate.longitude,updatedAt:Date(),items:items));WidgetCenter.shared.reloadAllTimelines();await NotificationScheduler.rescheduleIfAuthorized(settings:settings,items:allItems,timeZone:zone)}catch{errorMessage=error.localizedDescription}}
 func saveSettings() async {AppGroupStore.saveSettings(settings);if settings.locationMode == .fixed{await refreshFixedCity()}else if let currentLocation{await load(location:currentLocation,force:true)}else{locationService.start()};if settings.rules.contains(where:\.isEnabled){if (try? await NotificationScheduler.requestAuthorization()) == true{await NotificationScheduler.schedule(settings:settings,items:allItems,timeZone:timeZone)}}}
 func sendTestNotification() async {if (try? await NotificationScheduler.requestAuthorization()) == true{await NotificationScheduler.sendTestNotification()}}
}
