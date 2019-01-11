//
//  AudioInputView.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/15/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions
import AVFoundation

protocol AudioInputViewProtocol {
    var delegate: AudioInputViewDelegate? { get set }
    var presentingController: UIViewController? { get }
}

protocol AudioInputViewDelegate: class {
    func inputView(_ inputView: AudioInputViewProtocol, didFinishedRecording audio: Data)
    func inputViewDidRequestMicrophonePermission(_ inputView: AudioInputViewProtocol)
}

class AudioInputView: UIView, AudioInputViewProtocol, AVAudioRecorderDelegate {
    weak var delegate: AudioInputViewDelegate?
    weak var presentingController: UIViewController?

    private var recordButton: UIButton!
    private var holdToRecordLabel: UILabel!
    private var timerLabel: UILabel!
    private var cancelLabel: UILabel!

    private var view1: UIView!
    private var view2: UIView!
    private var view3: UIView!
    private var view4: UIView!
    private var view5: UIView!

    private var recordingSession: AVAudioSession!
    private var audioRecorder: AVAudioRecorder!
    private var timer = Timer()
    private var time: TimeInterval = 0

    init(presentingController: UIViewController?) {
        super.init(frame: CGRect.zero)
        self.presentingController = presentingController
        self.commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    private func commonInit() {
        self.backgroundColor = UIColor(rgb: 0x202124)
        self.configureAudio()
    }

    private func configureAudio() {
        self.recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.configureView()
                    } else {
                        Log.error("Permission to record audio was not granted")
                        // TODO: configure View with explanation why audio is not accessable
                    }
                }
            }
        } catch {
            Log.error(error.localizedDescription)
        }
    }

    private func configureView() {
        let view = UIView(frame: CGRect.zero)
        view.backgroundColor = UIColor(rgb: 0x202124)
        view.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(view)

        let horizontalConstraint = NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: self,
                                                      attribute: .top, multiplier: 1, constant: 0)
        let verticalConstraint = NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: self,
                                                    attribute: .leading, multiplier: 1, constant: 0)
        let widthConstraint = NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: self,
                                                 attribute: .width, multiplier: 1, constant: 0)
        let heightConstraint = NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: self,
                                                  attribute: .height, multiplier: 1, constant: 0)
        self.addConstraints([horizontalConstraint, verticalConstraint, widthConstraint, heightConstraint])

        self.configureView1(inside: view)
        self.configureHoldToRecordLabel(inside: view)
        self.configureView2(inside: view)
        self.configureTimerLabel(inside: view)
        self.configureView3(inside: view)
        self.configureRecordButton(inside: view)
        self.configureView4(inside: view)
        self.configureCancelLabel(inside: view)
        self.configureView5(inside: view)

        self.configureViewsProportions()
    }

    private func configureViewsProportions() {
        let constraint1 = NSLayoutConstraint(item: self.view1, attribute: .height, relatedBy: .equal,
                                             toItem: self.view2, attribute: .height, multiplier: 2, constant: 0)
        let constraint2 = NSLayoutConstraint(item: self.view1, attribute: .height, relatedBy: .equal,
                                             toItem: self.view3, attribute: .height, multiplier: 1, constant: 0)
        let constraint3 = NSLayoutConstraint(item: self.view1, attribute: .height, relatedBy: .equal,
                                             toItem: self.view4, attribute: .height, multiplier: 1, constant: 0)
        let constraint4 = NSLayoutConstraint(item: self.view1, attribute: .height, relatedBy: .equal,
                                             toItem: self.view5, attribute: .height, multiplier: 1, constant: 0)

        self.addConstraints([constraint1, constraint2, constraint3, constraint4])
    }

    private func configureView1(inside view: UIView) {
        self.view1 = UIView(frame: CGRect.zero)
        self.view1.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.view1)

        self.addConstraint(NSLayoutConstraint(item: self.view1, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view1, attribute: .top, relatedBy: .equal, toItem: view,
                                              attribute: .top, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view1, attribute: .width, relatedBy: .equal, toItem: view,
                                              attribute: .width, multiplier: 1, constant: 0))
    }

    private func configureHoldToRecordLabel(inside view: UIView) {
        self.holdToRecordLabel = UILabel(frame: CGRect.zero)
        self.holdToRecordLabel.textAlignment = .center
        self.holdToRecordLabel.translatesAutoresizingMaskIntoConstraints = false
        self.holdToRecordLabel.text = "Hold to record"
        self.holdToRecordLabel.textColor = UIColor(rgb: 0x909092)
        self.holdToRecordLabel.font = UIFont.systemFont(ofSize: 20)

        view.addSubview(self.holdToRecordLabel)

        self.addConstraint(NSLayoutConstraint(item: self.holdToRecordLabel, attribute: .top, relatedBy: .equal, toItem: self.view1,
                                              attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.holdToRecordLabel, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.holdToRecordLabel, attribute: .width, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 200))
        self.addConstraint(NSLayoutConstraint(item: self.holdToRecordLabel, attribute: .height, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 25))
    }

    private func configureView2(inside view: UIView) {
        self.view2 = UIView(frame: CGRect.zero)
        self.view2.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.view2)

        self.addConstraint(NSLayoutConstraint(item: self.view2, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view2, attribute: .top, relatedBy: .equal, toItem: self.holdToRecordLabel,
                                              attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view2, attribute: .width, relatedBy: .equal, toItem: view,
                                              attribute: .width, multiplier: 1, constant: 0))
    }

    private func configureTimerLabel(inside view: UIView) {
        self.timerLabel = UILabel.init(frame: CGRect.zero)
        self.timerLabel.textAlignment = .center
        self.timerLabel.translatesAutoresizingMaskIntoConstraints = false
        self.timerLabel.text = self.timeString(0)
        self.timerLabel.textColor = .white
        self.timerLabel.font = UIFont.boldSystemFont(ofSize: 18)

        view.addSubview(self.timerLabel)

        self.addConstraint(NSLayoutConstraint(item: self.timerLabel, attribute: .top, relatedBy: .equal, toItem: self.view2,
                                              attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.timerLabel, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.timerLabel, attribute: .width, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 200))
        self.addConstraint(NSLayoutConstraint(item: self.timerLabel, attribute: .height, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 25))
    }

    private func configureView3(inside view: UIView) {
        self.view3 = UIView(frame: CGRect.zero)
        self.view3.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.view3)

        self.addConstraint(NSLayoutConstraint(item: self.view3, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view3, attribute: .top, relatedBy: .equal, toItem: self.timerLabel,
                                              attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view3, attribute: .width, relatedBy: .equal, toItem: view,
                                              attribute: .width, multiplier: 1, constant: 0))
    }

    private func configureRecordButton(inside view: UIView) {
        self.recordButton = UIButton(frame: CGRect.zero)
        self.recordButton.translatesAutoresizingMaskIntoConstraints = false

        let image = UIImage(named: "button-record-voice", in: Bundle(for: AudioInputView.self), compatibleWith: nil)!
        self.recordButton.setImage(image, for: .normal)

        self.recordButton.addTarget(self, action: #selector(didStartRecord(_:)), for: .touchDown)
        self.recordButton.addTarget(self, action: #selector(didFinishRecord(_:)), for: .touchUpInside)
        self.recordButton.addTarget(self, action: #selector(didCancelRecord(_:)), for: .touchDragExit)
        view.addSubview(self.recordButton)

        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .top, relatedBy: .equal, toItem: self.view3,
                                              attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .width, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 100))
        self.addConstraint(NSLayoutConstraint(item: self.recordButton, attribute: .height, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 100))
    }

    private func configureView4(inside view: UIView) {
        self.view4 = UIView(frame: CGRect.zero)
        self.view4.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.view4)

        self.addConstraint(NSLayoutConstraint(item: self.view4, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view4, attribute: .top, relatedBy: .equal, toItem: self.recordButton,
                                              attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view4, attribute: .width, relatedBy: .equal, toItem: view,
                                              attribute: .width, multiplier: 1, constant: 0))
    }

    private func configureCancelLabel(inside view: UIView) {
        self.cancelLabel = UILabel(frame: CGRect.zero)
        self.cancelLabel.textAlignment = .center
        self.cancelLabel.translatesAutoresizingMaskIntoConstraints = false
        self.cancelLabel.text = "To cancel, drag your finger off Record"
        self.cancelLabel.textColor = UIColor(rgb: 0x909092)
        self.cancelLabel.font = UIFont.systemFont(ofSize: 16)
        self.cancelLabel.isHidden = false
        view.addSubview(self.cancelLabel)

        self.addConstraint(NSLayoutConstraint(item: self.cancelLabel, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.cancelLabel, attribute: .width, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 300))
        self.addConstraint(NSLayoutConstraint(item: self.cancelLabel, attribute: .height, relatedBy: .equal, toItem: nil,
                                              attribute: .notAnAttribute, multiplier: 1, constant: 30))
        self.addConstraint(NSLayoutConstraint(item: self.cancelLabel, attribute: .top, relatedBy: .equal, toItem: self.view4,
                                              attribute: .bottom, multiplier: 1, constant: 0))
    }

    private func configureView5(inside view: UIView) {
        self.view5 = UIView(frame: CGRect.zero)
        self.view5.translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(self.view5)

        self.addConstraint(NSLayoutConstraint(item: self.view5, attribute: .centerX, relatedBy: .equal, toItem: view,
                                              attribute: .centerX, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view5, attribute: .top, relatedBy: .equal, toItem: self.cancelLabel,
                                              attribute: .bottom, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view5, attribute: .width, relatedBy: .equal, toItem: view,
                                              attribute: .width, multiplier: 1, constant: 0))
        self.addConstraint(NSLayoutConstraint(item: self.view5, attribute: .bottom, relatedBy: .equal, toItem: view,
                                              attribute: .bottom, multiplier: 1, constant: 0))
    }

    @objc func didCancelRecord(_ sender: Any) {
        Log.debug("Canceled")
        self.finishRecording(success: false)
    }

    @objc func didStartRecord(_ sender: Any) {
        let imageTapped = UIImage(named: "button-stop-record", in: Bundle(for: AudioInputView.self), compatibleWith: nil)!
        self.recordButton.setImage(imageTapped, for: .normal)
        self.recordButton.setImage(imageTapped, for: .highlighted)
        self.cancelLabel.isHidden = false
        self.startRecording()
        self.holdToRecordLabel.text = "Recording..."
        self.timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(AudioInputView.updateTimer),
                                          userInfo: nil, repeats: true)
    }

    @objc func didFinishRecord(_ sender: Any) {
        self.finishRecording(success: self.time < 1 ? false : true)
    }
}

//Recording
extension AudioInputView {
    private func startRecording() {
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: self.getFileURL(), settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
        } catch {
            Log.error("Recording failed: \(error.localizedDescription)")
            finishRecording(success: false)
        }
    }

    private func finishRecording(success: Bool) {
        let image = UIImage(named: "button-record-voice", in: Bundle(for: AudioInputView.self), compatibleWith: nil)!
        self.recordButton.setImage(image, for: .normal)
        self.cancelLabel.isHidden = true
        audioRecorder.stop()
        audioRecorder = nil

        if success {
            do {
                let data = try Data(contentsOf: self.getFileURL(), options: [])
                self.delegate?.inputView(self, didFinishedRecording: data)
            } catch {
                Log.error(error.localizedDescription)
            }
        }
        self.timerLabel.text = self.timeString(0)
        self.holdToRecordLabel.text = "Hold to record"
        self.timer.invalidate()
        self.time = 0
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }

    @objc private func updateTimer() {
        self.time += 0.01
        self.timerLabel.text = self.timeString(self.time)
    }

    private func timeString(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        let miliseconds = Int((time - Double(Int(time))) * 100)

        return String(format:"%02i:%02i:%02i", minutes, seconds, miliseconds)
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func getFileURL() -> URL {
        let path = getDocumentsDirectory().appendingPathComponent("temp.m4a")
        return path
    }
}
