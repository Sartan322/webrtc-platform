
import Foundation
import WebRTC


class RTCSimulatorVideoDecoderFactory: RTCDefaultVideoDecoderFactory {
  
  override init() {
    super.init()
  }
  
  override func supportedCodecs() -> [RTCVideoCodecInfo] {
    var codecs = super.supportedCodecs()
    codecs = codecs.filter{$0.name != "H264"}
    return codecs
  }
}
