import SwiftUI
import AVFoundation

// MARK: - Audio Session Manager
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private init() {}
    
    func configure(for mode: Mode) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(mode.category)
        try session.setActive(true)
    }
    
    func deactivate() throws {
        try AVAudioSession.sharedInstance().setActive(false)
    }
    
    enum Mode {
        case record, playback
        
        var category: AVAudioSession.Category {
            switch self {
            case .record: return .record
            case .playback: return .playback
            }
        }
    }
}

// MARK: - Audio Recorder
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    private var recorder: AVAudioRecorder?
    
    func start(to url: URL) throws {
        try AudioSessionManager.shared.configure(for: .record)
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.record()
        isRecording = true
    }
    
    func stop() {
        recorder?.stop()
        isRecording = false
        try? AudioSessionManager.shared.deactivate()
    }
    
    // AVAudioRecorderDelegate methods
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        try? AudioSessionManager.shared.deactivate()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        isRecording = false
        try? AudioSessionManager.shared.deactivate()
    }
}

// MARK: - Audio Player
final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?
    
    func play(url: URL) throws {
        try AudioSessionManager.shared.configure(for: .playback)
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.play()
        isPlaying = true
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        try? AudioSessionManager.shared.deactivate()
    }
    
    // AVAudioPlayerDelegate methods
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        try? AudioSessionManager.shared.deactivate()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        try? AudioSessionManager.shared.deactivate()
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var isDarkMode = false
    
    var backgroundColor: Color {
        isDarkMode ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }
    
    var cardColor: Color {
        isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.3) : Color.white
    }
    
    var textColor: Color {
        isDarkMode ? Color.white : Color.primary
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer()
    @StateObject private var theme = ThemeManager()
    @State private var recordings: [URL] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRenameAlert = false
    @State private var newName = ""
    @State private var fileToRename: URL?
    @State private var showShareSheet = false
    @State private var fileToShare: URL?
    @State private var animationAmount: CGFloat = 1
    @State private var isPulsing = false
    
    // Colors with dark mode support
    var recordColor: Color { Color(red: 1.0, green: 0.23, blue: 0.19) }
    var playColor: Color { Color(red: 0.2, green: 0.78, blue: 0.35) }
    var renameColor: Color { Color(red: 1.0, green: 0.58, blue: 0.0) }
    var shareColor: Color { Color(red: 0.0, green: 0.48, blue: 1.0) }
    var deleteColor: Color { Color(red: 1.0, green: 0.27, blue: 0.23) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Theme Toggle
                    HStack {
                        Spacer()
                        Toggle("Dark Mode", isOn: $theme.isDarkMode)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding(.trailing, 20)
                            .labelsHidden()
                    }
                    
                    // Recording Section with Animation
                    VStack(spacing: 15) {
                        Text(recorder.isRecording ? "🔴 RECORDING" : "🎤 READY TO RECORD")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(recorder.isRecording ? recordColor : theme.textColor)
                            .shadow(color: theme.isDarkMode ? .clear : .black.opacity(0.1), radius: 2, x: 0, y: 2)
                        
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle()
                                    .fill(recorder.isRecording ? recordColor : Color.blue)
                                    .frame(width: 80, height: 80)
                                    .shadow(color: theme.isDarkMode ? .clear : .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                    .scaleEffect(animationAmount)
                                
                                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .onChange(of: recorder.isRecording) { isRecording in
                            if isRecording {
                                withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                                    animationAmount = 1.1
                                }
                            } else {
                                withAnimation {
                                    animationAmount = 1
                                }
                            }
                        }
                        
                        // Recording Visualization Animation
                        if recorder.isRecording {
                            HStack(spacing: 4) {
                                ForEach(0..<5) { i in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(recordColor)
                                        .frame(width: 6, height: CGFloat.random(in: 10...30))
                                        .animation(
                                            Animation.easeInOut(duration: 0.5)
                                                .repeatForever()
                                                .delay(Double(i) * 0.1),
                                            value: isPulsing
                                        )
                                }
                            }
                            .frame(height: 30)
                            .onAppear {
                                isPulsing.toggle()
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(theme.cardColor)
                            .shadow(color: theme.isDarkMode ? .clear : .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .padding(.horizontal, 20)
                    
                    // Recordings List
                    ScrollView {
                        VStack(spacing: 15) {
                            ForEach(recordings, id: \.self) { url in
                                RecordingRow(
                                    url: url,
                                    isPlaying: player.isPlaying,
                                    onPlay: { togglePlayback(url: url) },
                                    onRename: {
                                        fileToRename = url
                                        newName = url.deletingPathExtension().lastPathComponent
                                        showRenameAlert = true
                                    },
                                    onShare: {
                                        fileToShare = url
                                        showShareSheet = true
                                    },
                                    onDelete: { deleteRecording(url: url) },
                                    playColor: playColor,
                                    renameColor: renameColor,
                                    shareColor: shareColor,
                                    deleteColor: deleteColor,
                                    theme: theme
                                )
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding(.horizontal, 20)
                        .animation(.spring(), value: recordings)
                    }
                }
                .padding(.top, 20)
            }
            .navigationTitle("🎙️ Voice Memos")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Rename File", isPresented: $showRenameAlert) {
                TextField("New name", text: $newName)
                    .font(.title3)
                Button("Cancel", role: .cancel) { }
                Button("Rename", action: {
                    if let fileToRename = fileToRename {
                        renameRecording(from: fileToRename, to: newName)
                    }
                })
            }
            .sheet(isPresented: $showShareSheet) {
                if let fileToShare = fileToShare {
                    ShareSheet(activityItems: [fileToShare])
                        .preferredColorScheme(theme.isDarkMode ? .dark : .light)
                }
            }
            .onAppear {
                loadRecordings()
            }
            .preferredColorScheme(theme.isDarkMode ? .dark : .light)
        }
    }
    
    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stop()
            loadRecordings()
        } else {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            do {
                try recorder.start(to: url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func togglePlayback(url: URL) {
        if player.isPlaying {
            player.stop()
        } else {
            do {
                try player.play(url: url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func loadRecordings() {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordings = (try? FileManager.default.contentsOfDirectory(
            at: docsURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "m4a" }.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })) ?? []
    }
    
    private func deleteRecording(url: URL) {
        do {
            if player.isPlaying {
                player.stop()
            }
            try FileManager.default.removeItem(at: url)
            loadRecordings()
        } catch {
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func renameRecording(from oldURL: URL, to newName: String) {
        let newURL = oldURL.deletingLastPathComponent()
            .appendingPathComponent(newName)
            .appendingPathExtension("m4a")
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            loadRecordings()
        } catch {
            errorMessage = "Failed to rename: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Recording Row
struct RecordingRow: View {
    let url: URL
    let isPlaying: Bool
    let onPlay: () -> Void
    let onRename: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    let playColor: Color
    let renameColor: Color
    let shareColor: Color
    let deleteColor: Color
    @ObservedObject var theme: ThemeManager
    
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            Text(url.deletingPathExtension().lastPathComponent)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(theme.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            HStack(spacing: 15) {
                // Play Button with animation
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isPressed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isPressed = false
                        }
                    }
                    onPlay()
                }) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(playColor)
                        .clipShape(Circle())
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                }
                
                // Rename Button
                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(renameColor)
                        .clipShape(Circle())
                }
                
                // Share Button
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(shareColor)
                        .clipShape(Circle())
                }
                
                // Delete Button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(deleteColor)
                        .clipShape(Circle())
                }
            }
        }
        .padding(15)
        .background(theme.cardColor)
        .cornerRadius(15)
        .shadow(color: theme.isDarkMode ? .clear : .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Button Styles
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - App Entry
@main
struct VoiceMemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
