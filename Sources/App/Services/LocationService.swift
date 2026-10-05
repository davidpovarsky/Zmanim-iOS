import Combine
import CoreLocation
import Foundation
@MainActor final class LocationService:NSObject,ObservableObject,CLLocationManagerDelegate {
 private let manager=CLLocationManager(); private let geocoder=CLGeocoder(); @Published private(set) var location:CLLocation?; @Published private(set) var authorizationStatus:CLAuthorizationStatus = .notDetermined; @Published private(set) var errorMessage:String?; var onLocation:((CLLocation)->Void)?
 override init(){super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyHundredMeters;authorizationStatus=manager.authorizationStatus}
 func start(){ guard CLLocationManager.locationServicesEnabled() else {errorMessage="שירותי המיקום כבויים.";return}; switch manager.authorizationStatus {case .notDetermined:manager.requestWhenInUseAuthorization();case .authorizedAlways,.authorizedWhenInUse:manager.requestLocation();case .denied,.restricted:errorMessage="יש לאפשר גישה למיקום כדי לקבל זמני יום מדויקים.";default:break} }
 func refresh(){start()}
 func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){authorizationStatus=manager.authorizationStatus;if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {manager.requestLocation()}}
 func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){guard let newest=locations.last else{return};location=newest;errorMessage=nil;onLocation?(newest)}
 func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){errorMessage="לא הצלחנו לקבל את המיקום הנוכחי."}
 func describe(_ location:CLLocation) async -> (city:String,timeZone:TimeZone){do{let p=try await geocoder.reverseGeocodeLocation(location,preferredLocale:Locale(identifier:"he_IL"));guard let place=p.first else{return("המיקום הנוכחי",.current)};return(place.locality ?? place.subLocality ?? place.administrativeArea ?? "המיקום הנוכחי",place.timeZone ?? .current)}catch{return("המיקום הנוכחי",.current)}}
 func resolve(city:String) async throws -> (location:CLLocation,city:String,timeZone:TimeZone){let p=try await geocoder.geocodeAddressString(city,in:nil,preferredLocale:Locale(identifier:"he_IL"));guard let place=p.first,let location=place.location else{throw CLError(.geocodeFoundNoResult)};return(location,place.locality ?? place.name ?? city,place.timeZone ?? .current)}
}
