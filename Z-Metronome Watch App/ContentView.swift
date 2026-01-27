// 1/27/26 z-metronome
/*
 z-metronome for apple watch ios using swift
 provides a pulse indication from 40 to 200 beats per minute
 the independent selection indicators are:
 1) a click at 15.4k frequency
 2) an alternating flashing red background
 3) a haptics vibration
 */

import AVFoundation
import Combine
import SwiftUI
#if os(watchOS)
import WatchKit
#endif
#if os(iOS)
import UIKit
#endif

@Observable class MetronomeEngine {
    private var _engine = AVAudioEngine()
    private var _playerNode = AVAudioPlayerNode()
    private var _buffer: AVAudioPCMBuffer?
    private var _timer: AnyCancellable?
    private var _isRunning = false
    var _bpm: Double = 120.0
    var _isSoundOn = false
    var _isSightOn = false
    var _isFeelOn = false
    var _isLit = false
    init() {
        setupAudio()
        execute()
    }
    private func setupAudio() {
        _engine.attach(_playerNode)
        _engine.connect(_playerNode, to: _engine.mainMixerNode, format: nil)
        // Generate a simple click sound buffer
        let format = _playerNode.outputFormat(forBus: 0)
        let frameCount = AVAudioFrameCount(format.sampleRate * 0.05)  // 50ms click
        _buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        _buffer?.frameLength = frameCount
        // Fill buffer with simple sine wave click
        let gain: Float = 1.0  // 80% volume
        if let channelData = _buffer?.floatChannelData {
            for i in 0..<Int(frameCount) {
                //channelData[0][i] = sin(440.0 * Float(i) / Float(format.sampleRate)) * 0.5
                //channelData[0][i] = sin(880.0 * Float(i) / Float(format.sampleRate)) * gain
                //channelData[0][i] = sin(11000 * Float(i) / Float(format.sampleRate)) * 0.5
                //channelData[0][i] = sin(13200 * Float(i) / Float(format.sampleRate)) * 0.5
                channelData[0][i] =
                    sin(15400 * Float(i) / Float(format.sampleRate)) * gain
            }
            // find largest value from 0..1
            /*
            var largestValue:Float = 0.0
            for i in 0..<Int(frameCount) {
                // Multiply existing sample by gain
                if (channelData[0][i]) > largestValue {
                    largestValue = max(-1.0, min(1.0, channelData[0][i]))
                }
            }
            let delta:Float=1.0-largestValue
            // increase the gain by the difference between 1 and the largest value
            for i in 0..<Int(frameCount) {
                // Multiply existing sample by gain
                //channelData[0][i] += delta
                // Optional: Clamp to prevent digital clipping/distortion
                //channelData[0][i] = max(-1.0, min(1.0, channelData[0][i]))
            }
             */
        }
        try? _engine.start()
    }
    func setRunning(_ isRunning: Bool) {
        self._isRunning = isRunning
    }
    func isRunning() -> Bool {
        return _isRunning
    }
    func startStopToggle() {
        if isRunning() {
            stop()
        } else {
            start()
        }
    }
    func start() {
        setup()
        setRunning(true)
    }
    func stop() {
        _isLit = false
        setRunning(false)
        setdown()
    }
    func setup() {
        stop()
        // Schedule repeating clicks
        let interval = 60.0 / _bpm
        _timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.execute()
            }
    }
    func setdown() {
        _timer?.cancel()
    }
    func execute() {
        if isRunning() {
            if _isSoundOn == true {
                if let buffer = _buffer {
                    _playerNode.scheduleBuffer(
                        buffer,
                        at: nil,
                        options: [],
                        completionHandler: nil
                    )
                    if !_playerNode.isPlaying {
                        _playerNode.play()
                    }
                }
            }
            if _isSightOn == true { _isLit.toggle() } else { _isLit = false }
            if _isFeelOn == true {
                #if os(watchOS)
                WKInterfaceDevice.current().play(.start)
                #elseif os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
                #endif
            }
        }
    }
}

struct ContentView: View {
    @State var metronome = MetronomeEngine()
    @State private var isEditing = false
    @Environment(\.scenePhase) var scenePhrase: ScenePhase
    
    var body: some View {
        ZStack {
            Color.red
                .opacity(metronome._isLit ? 1.0 : 0.0)
                .edgesIgnoringSafeArea(.all)
                .onChange(of: scenePhrase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        //metronome.setRunning(true)
                        break
                    case .inactive:
                        metronome.setRunning(false)
                        break
                    case .background:
                        metronome.setRunning(false)
                        break
                    @unknown default:
                        metronome.setRunning(false)
                        break
                    }
                }
            VStack {
                HStack {
                    // toggle sight sound feel buttons
                    Button(action: {
                        metronome._isSoundOn.toggle()
                    }) {
                        Image(
                            systemName: metronome._isSoundOn
                                ? "speaker.wave.2.fill" : "speaker.wave.2"
                        )
                    }.tint(metronome._isSoundOn ? .yellow : .gray)
                    Button(action: {
                        metronome._isSightOn.toggle()
                    }) {
                        Image(
                            systemName: metronome._isSightOn
                                ? "lightbulb.max.fill" : "lightbulb.max"
                        )
                    }.tint(metronome._isSightOn ? .yellow : .gray)
                    Button(action: {
                        metronome._isFeelOn.toggle()
                    }) {
                        Image(
                            systemName: metronome._isFeelOn
                                ? "bell.and.waves.left.and.right.fill"
                                : "bell.and.waves.left.and.right"
                        )
                    }.tint(metronome._isFeelOn ? .yellow : .gray)
                }
                Text("\(Int(metronome._bpm)) BPM")
                    .font(.title3)
                Slider(
                    value: $metronome._bpm,
                    in: 40...200,
                    step: 1,
                    onEditingChanged: { editing in
                        isEditing = editing
                        if isEditing {
                            metronome.setRunning(false)
                        } else {
                            metronome.setup()
                            metronome.setRunning(true)
                        }
                    }
                ).padding(.horizontal)
                Button(action: {
                    metronome.startStopToggle()
                }) {
                    Image(
                        systemName: (metronome.isRunning())
                            ? "stop.fill" : "play.fill"
                    )
                }
                .tint(metronome.isRunning() ? .yellow : .gray)
            }
        }
    }
}
/*
 A320277
 A digitized pure tuning tone, sampled at standard settings for consumer audio: a(n) = floor(sin(2*Pi*(440/44100)*n)*32767).
 0
 0, 2052, 4097, 6126, 8130, 10103, 12036, 13921, 15752, 17521, 19222, 20846, 22389, 23844, 25205, 26467, 27625, 28675, 29612, 30433, 31134, 31713, 32167, 32494, 32695, 32766, 32709, 32524, 32210, 31770, 31206, 30518, 29711, 28787, 27750, 26604, 25354, 24004, 22559, 21026, 19410
 (list; graph; refs; listen; history; text; internal format)
 OFFSET
 0,2
 COMMENTS
 This sequence represents sample values for the simplest sound: a pure tone with no harmonics (i.e., a sine wave) with 0 phase shift, of digital peak amplitude, pitched at the standard tuning frequency (A440), and sampled at the standard sampling rate and bit depth resolution for consumer audio: 44100 Hz and 16 bits, respectively.
 Since the maximum signed integer value that can be stored in 16 bits is (2^15)-1=32767, the method used to convert the floats to integers is to multiply the floats by 32767 then cast to integer.
 The numerator and the denominator of the g.f. have degrees respectively equal to 2204 and 2205. -
 */
/*
 guard let floatData = buffer.floatChannelData else { return }
 let frameCount = Int(buffer.frameLength)
 let channelCount = Int(buffer.format.channelCount)
 let gain: Float = 1.5 // Amplify by 150%

 for channel in 0..<channelCount {
     for i in 0..<frameCount {
         // Multiply existing sample by gain
         floatData[channel][i] *= gain

         // Optional: Clamp to prevent digital clipping/distortion
         floatData[channel][i] = max(-1.0, min(1.0, floatData[channel][i]))
     }
 }

 */

