import SwiftUI
extension Color { static let zmanBackground=Color(red:0.972,green:0.966,blue:0.936); static let zmanCard=Color(red:0.965,green:0.945,blue:0.885); static let zmanInk=Color(red:0.105,green:0.105,blue:0.20); static let zmanIndigo=Color(red:0.245,green:0.245,blue:0.56); static let zmanOrange=Color(red:0.93,green:0.50,blue:0.20); static let zmanNight=Color(red:0.35,green:0.29,blue:0.55) }
struct ZmanCardModifier:ViewModifier { func body(content:Content)->some View { content.background(RoundedRectangle(cornerRadius:24,style:.continuous).fill(Color.zmanCard.opacity(0.72)).overlay(RoundedRectangle(cornerRadius:24,style:.continuous).stroke(Color.zmanInk.opacity(0.12),lineWidth:1))) } }
extension View { func zmanCard()->some View { modifier(ZmanCardModifier()) } }
