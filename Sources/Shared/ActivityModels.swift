import ActivityKit
import Foundation
struct ZmanimActivityAttributes:ActivityAttributes { struct ContentState:Codable,Hashable { var title:String; var targetDate:Date; var icon:String }; var cityName:String }
