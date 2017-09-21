import AudioKit
import AVFoundation
import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var microphoneButton: UIButton!
    @IBOutlet weak var mainLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var urlRecognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        microphoneButton.isEnabled = false
        
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.microphoneButton.isEnabled = isButtonEnabled
            }
        }
    }
    
    @IBAction func microphoneTapped(_ sender: AnyObject) {
//        if audioEngine.isRunning {
//            audioEngine.stop()
//            recognitionRequest?.endAudio()
//            microphoneButton.isEnabled = false
//            microphoneButton.setTitle("Start Recording", for: .normal)
//        } else {
//            startRecording()
//            microphoneButton.setTitle("Stop Recording", for: .normal)
//        }
        startRecognizing()
    }
    @IBAction func playTapped(_ sender: AnyObject) {
        let audioFile = try? AKAudioFile(readFileName: "Pollution.m4a", baseDir: .resources)
        if (audioFile != nil){
            let player = try! AKAudioPlayer(file: audioFile!)
            mainLabel.text = "Loaded file"
            AudioKit.output = player
            AudioKit.start()
            playButton.setTitle("Playing file", for: .normal)
            player.play()
        }
        else {
            mainLabel.text = "File loading error"
        }
    }
    
    func startRecognizing() {
        guard let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US")) else {
            mainLabel.text = "Could not init Speech Recognizer"
            return
        }
        
        let fileUrl = URL(fileURLWithPath: Bundle.main.path(forResource: "Pollution", ofType:"m4a")!)
        
        let urlRecognitionRequest = SFSpeechURLRecognitionRequest(url: fileUrl)
        microphoneButton.setTitle("Transcribing...", for: .normal)
        recognitionTask = speechRecognizer.recognitionTask(with: urlRecognitionRequest, resultHandler: { (result, error) in
                print(result?.bestTranscription ?? "")
            if (result?.isFinal)! {
                self.mainLabel.text = result?.bestTranscription.formattedString
            }
        })}
    
    func startRecording() {
        
        if recognitionTask != nil {  //1
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()  //2
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()  //3
        
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }  //4
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        } //5
        
        recognitionRequest.shouldReportPartialResults = true  //6
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in  //7
            
            var isFinal = false  //8
            
            if result != nil {
                
                self.textView.text = result?.bestTranscription.formattedString  //9
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {  //10
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.microphoneButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)  //11
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()  //12
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        textView.text = "Say something, I'm listening!"
        
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            microphoneButton.isEnabled = true
        } else {
            microphoneButton.isEnabled = false
        }
    }
}
