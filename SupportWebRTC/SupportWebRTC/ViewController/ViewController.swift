
import UIKit
import Starscream
import WebRTC
import UIKit

class ViewController: UIViewController, WebSocketDelegate, WebRTCClientDelegate, CameraSessionDelegate {
  
  enum messageType {
    case greet
    case introduce
    
    func text() -> String {
      switch self {
      case .greet:
        return "Hello!"
      case .introduce:
        return "I'm " + UIDevice.modelName
      }
    }
  }
  
  //MARK: - Properties
  var webRTCClient: WebRTCClient!
  var socket: WebSocket!
  var tryToConnectWebSocket: Timer!
  var cameraSession: CameraSession?
  
  // You can create video source from CMSampleBuffer :)
  var useCustomCapturer: Bool = false
  var cameraFilter: CameraFilter?
  
  // Constants
  // MARK: Change this ip address in your case
  let ipAddress: String = "192.168.0.101"
  let wsStatusMessageBase = "WebSocket: "
  let webRTCStatusMesasgeBase = "WebRTC: "
  let likeStr: String = "Like"
  
  // UI
  lazy var wsStatusLabel: UILabel = {
    let label = UILabel()
    label.text = webRTCStatusMesasgeBase + "initialized"
    label.textColor = .blue
    return label
  }()
  
  lazy var webRTCStatusLabel: UILabel = {
    let label = UILabel()
    label.text = webRTCStatusMesasgeBase + "initialized"
    label.textColor = .blue
    return label
  }()
  var webRTCMessageLabel: UILabel!
  let likeImage = UIImage(named: "like_filled.png")
  lazy var likeImageViewRect = CGRect(x: view.center.x, y: view.center.y, width: 60, height: 60)
  
  let callButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(named: "phone")?.withRenderingMode(.alwaysOriginal), for: .normal)
    button.setImage(UIImage(named: "phone.down")?.withRenderingMode(.alwaysOriginal), for: .selected)
    button.backgroundColor = .systemBlue
    button.layer.cornerRadius = 30
    return button
  }()
  
  let likeButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(named: "heart")?.withRenderingMode(.alwaysOriginal), for: .normal)
    button.layer.cornerRadius = 30
    button.layer.borderWidth = 2
    button.layer.borderColor = UIColor.red.cgColor
    return button
  }()
  
  let drawButton: UIButton = {
    let button = UIButton(type: .system)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.setImage(UIImage(named: "hand.draw")?.withRenderingMode(.alwaysOriginal), for: .normal)
    button.setImage(UIImage(named: "hand.draw.stop")?.withRenderingMode(.alwaysOriginal), for: .selected)
    button.backgroundColor = .systemBlue
    button.layer.cornerRadius = 30
    return button
  }()
  
  var localRenderViewGasture: UITapGestureRecognizer?
  
  lazy var localRenderView: RTCEAGLVideoView = {
    let view = RTCEAGLVideoView()
    view.translatesAutoresizingMaskIntoConstraints = false
    webRTCClient.localRenderView = view
    view.delegate = webRTCClient
    view.backgroundColor = .gray
    let tap = UITapGestureRecognizer(target: self, action: #selector(localVideoViewTapped))
    localRenderViewGasture = tap
    view.addGestureRecognizer(tap)
    return view
  }()
  
  lazy var remoteRenderView: RTCEAGLVideoView = {
    let view = RTCEAGLVideoView()
    view.translatesAutoresizingMaskIntoConstraints = false
    webRTCClient.remoteRenderView = view
    view.delegate = webRTCClient
    view.backgroundColor = .gray
    return view
  }()
  
  let drawingView = DrawingView()
  let canvas = Canvas()
  
  //MARK: - ViewController Override Methods
  override func viewDidLoad() {
    super.viewDidLoad()
#if targetEnvironment(simulator)
    // simulator does not have camera
    self.useCustomCapturer = false
#endif
    
    webRTCClient = WebRTCClient()
    setupUI()
    webRTCClient.delegate = self
    webRTCClient.setup(videoTrack: true, audioTrack: true, dataChannel: true, customFrameCapturer: useCustomCapturer)
    
    if useCustomCapturer {
      print("--- use custom capturer ---")
      self.cameraSession = CameraSession()
      self.cameraSession?.delegate = self
      self.cameraSession?.setupSession()
      
      self.cameraFilter = CameraFilter()
    }
    
    socket = WebSocket(url: URL(string: "ws://" + ipAddress + ":8080/")!)
    socket.delegate = self
    
    tryToConnectWebSocket = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { (timer) in
      if self.webRTCClient.isConnected || self.socket.isConnected {
        return
      }
      
      self.socket.connect()
    })
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - UI
  private func setupUI(){
    view.backgroundColor = .gray
    // Main View
    let remoteVideoView = UIView()
    remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
    remoteVideoView.addSubview(remoteRenderView)
    view.addSubview(remoteVideoView)
    
    let localVideoView = UIView()
    localVideoView.translatesAutoresizingMaskIntoConstraints = false
    localVideoView.subviews.last?.isUserInteractionEnabled = true
    localVideoView.layer.cornerRadius = 8
    localVideoView.backgroundColor = .red
    localVideoView.addSubview(localRenderView)
    view.addSubview(localVideoView)
    
    let localVideoViewButton = UIButton(frame: CGRect(x: 0, y: 0, width: localVideoView.frame.width, height: localVideoView.frame.height))
    localVideoViewButton.backgroundColor = UIColor.clear
    localVideoViewButton.addTarget(self, action: #selector(self.localVideoViewTapped(_:)), for: .touchUpInside)
    localVideoView.addSubview(localVideoViewButton)
    
    // Buttons
    let buttonStackView = UIStackView(arrangedSubviews: [callButton, likeButton, drawButton])
    buttonStackView.translatesAutoresizingMaskIntoConstraints = false
    buttonStackView.spacing = 5
    view.addSubview(buttonStackView)
    callButton.addTarget(self, action: #selector(didTapCallButton), for: .touchUpInside)
    likeButton.addTarget(self, action: #selector(likeButtonTapped), for: .touchUpInside)
    drawButton.addTarget(self, action: #selector(drawButtonDidTap), for: .touchUpInside)
    
    // Texts
    let textsStackView = UIStackView(arrangedSubviews: [webRTCStatusLabel, wsStatusLabel])
    textsStackView.translatesAutoresizingMaskIntoConstraints = false
    textsStackView.axis = .vertical
    view.addSubview(textsStackView)
    
    canvas.translatesAutoresizingMaskIntoConstraints = false
    canvas.isHidden = true
    //    canvas.backgroundColor = .white.withAlphaComponent(0.1)
    canvas.isUserInteractionEnabled = true
    remoteVideoView.addSubview(canvas)
    
    
    let safeArea = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      remoteVideoView.topAnchor.constraint(lessThanOrEqualTo: safeArea.topAnchor),
      remoteVideoView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
      remoteVideoView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
      remoteVideoView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor),
      remoteVideoView.widthAnchor.constraint(equalTo: safeArea.widthAnchor),
      remoteVideoView.heightAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 1.36),
      remoteVideoView.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
      remoteVideoView.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
      
      remoteRenderView.topAnchor.constraint(lessThanOrEqualTo: remoteVideoView.topAnchor),
      remoteRenderView.leadingAnchor.constraint(equalTo: remoteVideoView.leadingAnchor),
      remoteRenderView.trailingAnchor.constraint(equalTo: remoteVideoView.trailingAnchor),
      remoteRenderView.bottomAnchor.constraint(lessThanOrEqualTo: remoteVideoView.bottomAnchor),
      
      localVideoView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.33),
      localVideoView.heightAnchor.constraint(equalTo: localVideoView.widthAnchor, multiplier: 1.36),
      localVideoView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -5),
      localVideoView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -5),
      
      localRenderView.topAnchor.constraint(lessThanOrEqualTo: localVideoView.topAnchor),
      localRenderView.leadingAnchor.constraint(equalTo: localVideoView.leadingAnchor),
      localRenderView.trailingAnchor.constraint(equalTo: localVideoView.trailingAnchor),
      localRenderView.bottomAnchor.constraint(lessThanOrEqualTo: localVideoView.bottomAnchor),
      
      textsStackView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 10),
      textsStackView.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -10),
      textsStackView.trailingAnchor.constraint(equalTo: localVideoView.leadingAnchor, constant: -10),
      
      callButton.widthAnchor.constraint(equalToConstant: 60),
      callButton.heightAnchor.constraint(equalToConstant: 60),
      likeButton.widthAnchor.constraint(equalToConstant: 60),
      likeButton.heightAnchor.constraint(equalToConstant: 60),
      drawButton.widthAnchor.constraint(equalToConstant: 60),
      drawButton.heightAnchor.constraint(equalToConstant: 60),
      buttonStackView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 10),
      buttonStackView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -5),
      
      canvas.topAnchor.constraint(equalTo: remoteVideoView.topAnchor),
      canvas.leadingAnchor.constraint(equalTo: remoteVideoView.leadingAnchor),
      canvas.trailingAnchor.constraint(equalTo: remoteVideoView.trailingAnchor),
      canvas.bottomAnchor.constraint(equalTo: remoteVideoView.bottomAnchor),
    ])
    
    //    let likeButton = UIButton(frame: .zero)
    //    likeButton.backgroundColor = UIColor.clear
    //    likeButton.addTarget(self, action: #selector(self.likeButtonTapped(_:)), for: .touchUpInside)
    //    view.addSubview(likeButton)
    //    likeButton.setImage(UIImage(named: "like_border.png"), for: .normal)
    //
    //    likeImage = UIImage(named: "like_filled.png")
    //    likeImageViewRect = CGRect(x: remoteVideoViewContainter.right - 70, y: likeButton.top - 70, width: 60, height: 60)
    //
    //    let messageButton = UIButton(frame: CGRect(x: likeButton.left - 220, y: remoteVideoViewContainter.bottom - 50, width: 210, height: 40))
    //    messageButton.setBackgroundImage(UIColor.green.rectImage(width: messageButton.frame.width, height: messageButton.frame.height), for: .normal)
    //    messageButton.addTarget(self, action: #selector(self.sendMessageButtonTapped(_:)), for: .touchUpInside)
    //    messageButton.titleLabel?.adjustsFontSizeToFitWidth = true
    //    messageButton.setTitle(messageType.greet.text(), for: .normal)
    //    messageButton.layer.cornerRadius = 20
    //    messageButton.layer.masksToBounds = true
    //    view.addSubview(messageButton)
    //
    //    wsStatusLabel = UILabel(frame: CGRect(x: 0, y: remoteVideoViewContainter.bottom, width: ScreenSizeUtil.width(), height: 30))
    //    wsStatusLabel.textAlignment = .center
    //    view.addSubview(wsStatusLabel)
    //    webRTCStatusLabel = UILabel(frame: CGRect(x: 0, y: wsStatusLabel.bottom, width: ScreenSizeUtil.width(), height: 30))
    //    webRTCStatusLabel.textAlignment = .center
    //    webRTCStatusLabel.text = webRTCStatusMesasgeBase + "initialized"
    //    view.addSubview(webRTCStatusLabel)
    //    webRTCMessageLabel = UILabel(frame: CGRect(x: 0, y: webRTCStatusLabel.bottom, width: ScreenSizeUtil.width(), height: 30))
    //    webRTCMessageLabel.textAlignment = .center
    //    webRTCMessageLabel.textColor = .black
    //    view.addSubview(webRTCMessageLabel)
    //
    //    let buttonWidth = ScreenSizeUtil.width()*0.4
    //    let buttonHeight: CGFloat = 60
    //    let buttonRadius: CGFloat = 30
    //    let callButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))
    //    callButton.setBackgroundImage(UIColor.blue.rectImage(width: callButton.frame.width, height: callButton.frame.height), for: .normal)
    //    callButton.layer.cornerRadius = buttonRadius
    //    callButton.layer.masksToBounds = true
    //    callButton.center.x = ScreenSizeUtil.width()/4
    //    callButton.center.y = webRTCStatusLabel.bottom + (ScreenSizeUtil.height() - webRTCStatusLabel.bottom)/2
    //    callButton.setTitle("Call", for: .normal)
    //    callButton.titleLabel?.font = UIFont.systemFont(ofSize: 23)
    //    callButton.addTarget(self, action: #selector(self.callButtonTapped(_:)), for: .touchUpInside)
    //    view.addSubview(callButton)
    //
    //    let hangupButton = UIButton(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))
    //    hangupButton.setBackgroundImage(UIColor.red.rectImage(width: hangupButton.frame.width, height: hangupButton.frame.height), for: .normal)
    //    hangupButton.layer.cornerRadius = buttonRadius
    //    hangupButton.layer.masksToBounds = true
    //    hangupButton.center.x = ScreenSizeUtil.width()/4 * 3
    //    hangupButton.center.y = callButton.center.y
    //    hangupButton.setTitle("hang up" , for: .normal)
    //    hangupButton.titleLabel?.font = UIFont.systemFont(ofSize: 22)
    //    hangupButton.addTarget(self, action: #selector(self.hangupButtonTapped(_:)), for: .touchUpInside)
    //    view.addSubview(hangupButton)
  }
  
  // MARK: - UI Events
  @objc
  func didTapCallButton() {
    if webRTCClient.isConnected {
      webRTCClient.disconnect()
      callButton.isSelected = false
    } else {
      webRTCClient.connect(onSuccess: { [weak self] (offerSDP: RTCSessionDescription) -> Void in
        self?.sendSDP(sessionDescription: offerSDP)
        DispatchQueue.main.async {
          self?.callButton.isSelected = true
        }
      })
    }
    
  }
  //
  //  @objc
  //  func hangupButtonTapped(_ sender: UIButton){
  //    if webRTCClient.isConnected {
  //      webRTCClient.disconnect()
  //    }
  //  }
  
  @objc
  func sendMessageButtonTapped(_ sender: UIButton){
    webRTCClient.sendMessge(message: (sender.titleLabel?.text!)!)
    if sender.titleLabel?.text == messageType.greet.text() {
      sender.setTitle(messageType.introduce.text(), for: .normal)
    }else if sender.titleLabel?.text == messageType.introduce.text() {
      sender.setTitle(messageType.greet.text(), for: .normal)
    }
  }
  
  @objc
  func likeButtonTapped(_ sender: UIButton){
    let data = likeStr.data(using: String.Encoding.utf8)
    webRTCClient.sendData(data: data!)
  }
  
  @objc
  func drawButtonDidTap() {
    drawButton.isSelected.toggle()
    canvas.isHidden = !drawButton.isSelected
    
    if canvas.isHidden {
      DispatchQueue.main.async {
        
        let snapshot = self.canvas.saveData()
        snapshot?.imageRendererFormat.opaque = true
        guard let snapshot else { return }
        print("asd")
        let image = UIView()
        image.backgroundColor = UIColor(patternImage: snapshot)
        //        image.backgroundColor = .green
//        image.isOpaque = false
        image.translatesAutoresizingMaskIntoConstraints = false
        self.remoteRenderView.addSubview(image)
        //      image.backgroundColor = .green
        NSLayoutConstraint.activate([
          image.heightAnchor.constraint(equalToConstant: self.canvas.bounds.height),
          image.widthAnchor.constraint(equalToConstant: self.canvas.bounds.width),
          image.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
          image.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
        
      }
    }
    //    drawingView.isHidden = !drawButton.isSelected
    //    if drawingView.isHidden {
    //
    //      let viewSnapshot = drawingView.saveData()
    //      drawingView.clearCanvas()
    //      guard let viewSnapshot else { return }
    //      DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    ////        let image = UIImage(data: viewSnapshot)
    //        self.drawingView.image = viewSnapshot
    ////        self.drawingView.isHidden = false
    //        let imageView = UIImageView(image: viewSnapshot)
    //        imageView.backgroundColor = .white
    //        imageView.translatesAutoresizingMaskIntoConstraints = false
    //        self.remoteRenderView.addSubview(imageView)
    //
    //        NSLayoutConstraint.activate([
    //          imageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
    //          imageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
    //          imageView.widthAnchor.constraint(equalToConstant: 300),
    //          imageView.heightAnchor.constraint(equalToConstant: 300)
    //        ])
    //      }
    //    }
  }
  
  @objc
  func localVideoViewTapped(_ sender: UITapGestureRecognizer) {
    //        if let filter = self.cameraFilter {
    //            filter.changeFilter(filter.filterType.next())
    //        }
    webRTCClient.switchCameraPosition()
  }
  
  private func startLikeAnimation(){
    let likeImageView = UIImageView(frame: likeImageViewRect)
    likeImageView.backgroundColor = UIColor.clear
    likeImageView.contentMode = .scaleAspectFit
    likeImageView.image = likeImage
    likeImageView.alpha = 1.0
    self.view.addSubview(likeImageView)
    UIView.animate(withDuration: 0.5, animations: {
      likeImageView.alpha = 0.0
    }) { (reuslt) in
      likeImageView.removeFromSuperview()
    }
  }
  
  // MARK: - WebRTC Signaling
  private func sendSDP(sessionDescription: RTCSessionDescription){
    var type = ""
    if sessionDescription.type == .offer {
      type = "offer"
    }else if sessionDescription.type == .answer {
      type = "answer"
    }
    
    let sdp = SDP.init(sdp: sessionDescription.sdp)
    let signalingMessage = SignalingMessage.init(type: type, sessionDescription: sdp, candidate: nil)
    do {
      let data = try JSONEncoder().encode(signalingMessage)
      let message = String(data: data, encoding: String.Encoding.utf8)!
      
      if self.socket.isConnected {
        self.socket.write(string: message)
      }
    }catch{
      print(error)
    }
  }
  
  private func sendCandidate(iceCandidate: RTCIceCandidate){
    let candidate = Candidate.init(sdp: iceCandidate.sdp, sdpMLineIndex: iceCandidate.sdpMLineIndex, sdpMid: iceCandidate.sdpMid!)
    let signalingMessage = SignalingMessage.init(type: "candidate", sessionDescription: nil, candidate: candidate)
    do {
      let data = try JSONEncoder().encode(signalingMessage)
      let message = String(data: data, encoding: String.Encoding.utf8)!
      
      if self.socket.isConnected {
        self.socket.write(string: message)
      }
    }catch{
      print(error)
    }
  }
  
}

// MARK: - WebSocket Delegate
extension ViewController {
  
  func websocketDidConnect(socket: WebSocketClient) {
    print("-- websocket did connect --")
    wsStatusLabel.text = wsStatusMessageBase + "connected"
    wsStatusLabel.textColor = .green
  }
  
  func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
    print("-- websocket did disconnect --")
    wsStatusLabel.text = wsStatusMessageBase + "disconnected"
    wsStatusLabel.textColor = .red
  }
  
  func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
    
    do{
      let signalingMessage = try JSONDecoder().decode(SignalingMessage.self, from: text.data(using: .utf8)!)
      
      if signalingMessage.type == "offer" {
        webRTCClient.receiveOffer(offerSDP: RTCSessionDescription(type: .offer, sdp: (signalingMessage.sessionDescription?.sdp)!), onCreateAnswer: {(answerSDP: RTCSessionDescription) -> Void in
          self.sendSDP(sessionDescription: answerSDP)
        })
      }else if signalingMessage.type == "answer" {
        webRTCClient.receiveAnswer(answerSDP: RTCSessionDescription(type: .answer, sdp: (signalingMessage.sessionDescription?.sdp)!))
      }else if signalingMessage.type == "candidate" {
        let candidate = signalingMessage.candidate!
        webRTCClient.receiveCandidate(candidate: RTCIceCandidate(sdp: candidate.sdp, sdpMLineIndex: candidate.sdpMLineIndex, sdpMid: candidate.sdpMid))
      }
    }catch{
      print(error)
    }
    
  }
  
  func websocketDidReceiveData(socket: WebSocketClient, data: Data) { }
}

// MARK: - WebRTCClient Delegate
extension ViewController {
  func didGenerateCandidate(iceCandidate: RTCIceCandidate) {
    self.sendCandidate(iceCandidate: iceCandidate)
  }
  
  func didIceConnectionStateChanged(iceConnectionState: RTCIceConnectionState) {
    var state = ""
    
    switch iceConnectionState {
    case .checking:
      state = "checking..."
    case .closed:
      state = "closed"
      callButton.isSelected = false
    case .completed:
      state = "completed"
    case .connected:
      state = "connected"
      callButton.isSelected = true
    case .count:
      state = "count..."
    case .disconnected:
      state = "disconnected"
      callButton.isSelected = false
    case .failed:
      state = "failed"
    case .new:
      state = "new..."
    }
    self.webRTCStatusLabel.text = self.webRTCStatusMesasgeBase + state
  }
  
  func didConnectWebRTC() {
    self.webRTCStatusLabel.textColor = .green
    // MARK: Disconnect websocket
    self.socket.disconnect()
    callButton.isSelected = true
  }
  
  func didDisconnectWebRTC() {
    self.webRTCStatusLabel.textColor = .red
    callButton.isSelected = false
  }
  
  func didOpenDataChannel() {
    print("did open data channel")
  }
  
  func didReceiveData(data: Data) {
    if data == likeStr.data(using: String.Encoding.utf8) {
      self.startLikeAnimation()
    }
  }
  
  func didReceiveMessage(message: String) {
    self.webRTCMessageLabel.text = message
  }
}

// MARK: - CameraSessionDelegate
extension ViewController {
  func didOutput(_ sampleBuffer: CMSampleBuffer) {
    if self.useCustomCapturer {
      if let cvpixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer){
        if let buffer = self.cameraFilter?.apply(cvpixelBuffer){
          self.webRTCClient.captureCurrentFrame(sampleBuffer: buffer)
        }else{
          print("no applied image")
        }
      }else{
        print("no pixelbuffer")
      }
      //            self.webRTCClient.captureCurrentFrame(sampleBuffer: buffer)
    }
  }
}

extension UIView{
  func createImageData(quality: CGFloat = 0.8) -> Data {
    let renderFormat = UIGraphicsImageRendererFormat.default()
    renderFormat.opaque = false
    self.isOpaque = false
    self.layer.isOpaque = true
    self.backgroundColor = UIColor.clear
    self.layer.backgroundColor = UIColor.clear.cgColor
    let renderer = UIGraphicsImageRenderer(size: bounds.size, format: renderFormat)
    return renderer.jpegData(withCompressionQuality: quality, actions: { context in
      layer.render(in: context.cgContext)
    })
  }
}
