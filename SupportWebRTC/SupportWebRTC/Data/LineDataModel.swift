
import Foundation

struct LineDataModel: Codable {
  let id: UUID
  let color: [Int]
  let points: [CGPoint]
  let lineWidth: Int
}
