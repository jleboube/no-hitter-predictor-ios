import WidgetKit
import SwiftUI
import Foundation
import UIKit
import UIKit

struct PredictionEntry: TimelineEntry {
    let date: Date
    let prediction: NoHitterPrediction?
    let imageData: Data?
    let isPlaceholder: Bool

    var headshotImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }

    static let placeholder = PredictionEntry(date: Date(), prediction: SampleData.prediction, imageData: nil, isPlaceholder: true)
}
