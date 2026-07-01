import AVFoundation
import Foundation

enum AudioProcessorError: LocalizedError {
  case unsupportedAudio

  var errorDescription: String? {
    "この音声形式を読み込めません。WAV、M4A、MP3をお試しください。"
  }
}

enum AudioProcessor {
  static func convertToWav(path: String) throws -> String {
    let input: AVAudioFile
    do {
      input = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    } catch {
      throw AudioProcessorError.unsupportedAudio
    }
    let inputFormat = input.processingFormat
    guard
      let inputBuffer = AVAudioPCMBuffer(
        pcmFormat: inputFormat,
        frameCapacity: AVAudioFrameCount(input.length)
      )
    else { throw AudioProcessorError.unsupportedAudio }
    try input.read(into: inputBuffer)
    guard let inputChannels = inputBuffer.floatChannelData else {
      throw AudioProcessorError.unsupportedAudio
    }

    guard
      let monoFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: inputFormat.sampleRate,
        channels: 1,
        interleaved: false
      ),
      let monoBuffer = AVAudioPCMBuffer(
        pcmFormat: monoFormat,
        frameCapacity: inputBuffer.frameLength
      ),
      let destination = monoBuffer.floatChannelData?[0]
    else { throw AudioProcessorError.unsupportedAudio }

    let frameCount = Int(inputBuffer.frameLength)
    let channelCount = Int(inputFormat.channelCount)
    monoBuffer.frameLength = inputBuffer.frameLength
    for frame in 0..<frameCount {
      var sample: Float = 0
      for channel in 0..<channelCount {
        sample += inputChannels[channel][frame]
      }
      destination[frame] = sample / Float(channelCount)
    }

    let fileManager = FileManager.default
    let documents = try fileManager.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let convertedDirectory = documents.appendingPathComponent("converted", isDirectory: true)
    try fileManager.createDirectory(at: convertedDirectory, withIntermediateDirectories: true)
    let outputURL = convertedDirectory.appendingPathComponent(
      "decoded_\(UUID().uuidString).wav"
    )
    let output = try AVAudioFile(forWriting: outputURL, settings: monoFormat.settings)
    try output.write(from: monoBuffer)
    return outputURL.path
  }
}
