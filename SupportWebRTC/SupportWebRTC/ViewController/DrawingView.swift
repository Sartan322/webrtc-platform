
import UIKit

class DrawingView: UIImageView {
  
  var startingPoint: CGPoint?
  var touchPoint: CGPoint?
  var path: UIBezierPath?
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    startingPoint = touch.location(in: self)
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch  = touches.first else { return }
    touchPoint = touch.location(in: self)
    
    guard let touchPoint, let startingPoint else { return }
    
    path = UIBezierPath()
    path?.move(to: startingPoint)
    path?.addLine(to: touchPoint)
    self.startingPoint = touchPoint
    
    drawShapeLayer()
  }
  
  func drawShapeLayer() {
    let shapeLayer = CAShapeLayer()
    shapeLayer.path = path?.cgPath
    shapeLayer.strokeColor = UIColor.red.cgColor
    shapeLayer.lineWidth = 5
    shapeLayer.fillColor = UIColor.red.cgColor
    self.layer.addSublayer(shapeLayer)
    self.setNeedsDisplay()
  }
  
  func clearCanvas() {
    path?.removeAllPoints()
    self.layer.sublayers = nil
    self.setNeedsDisplay()
  }
  
  func saveData() -> Data? {
    
    layer.sublayers?.forEach({ layer in
      
    })
    UIGraphicsBeginImageContext(bounds.size)
    
    layer.render(in: UIGraphicsGetCurrentContext()!)
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image?.jpegData(compressionQuality: 1)
  }
}

class Canvas: UIView {
  
  override func draw(_ rect: CGRect) {
    super.draw(rect)
        
    guard let context = UIGraphicsGetCurrentContext() else { return }
    
    
    //        let startPoint = CGPoint(x: 0, y: 0)
    //        let endPoint = CGPoint(x: 100, y: 100)
    //
    //        context.move(to: startPoint)
    //        context.addLine(to: endPoint)
    
    context.setStrokeColor(UIColor.red.cgColor)
    context.setLineWidth(5)
    context.setLineCap(.butt)
    
    lines.forEach { (line) in
      for (i, p) in line.enumerated() {
        if i == 0 {
          context.move(to: p)
        } else {
          context.addLine(to: p)
        }
      }
    }
    
    context.strokePath()
    
  }
  
  var lines = [[CGPoint]]()
  var lineDataModels: [LineDataModel] = []
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    UIGraphicsBeginImageContext(bounds.size)
    lines.append([CGPoint]())
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let point = touches.first?.location(in: self) else { return }
    //        print(point)
    
    guard var lastLine = lines.popLast() else { return }
    lastLine.append(point)
    lines.append(lastLine)
    
    //        var lastLine = lines.last
    //        lastLine?.append(point)
    
    //        line.append(point)
    
    setNeedsDisplay()
  }
  
  func saveData() -> UIImage? {
    
    if let context = UIGraphicsGetCurrentContext() {
      layer.render(in: context)
    }
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image
  }
}

