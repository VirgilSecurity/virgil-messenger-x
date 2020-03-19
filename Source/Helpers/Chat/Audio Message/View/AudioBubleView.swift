//
//  AudioBubleView.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Chatto
import ChattoAdditions

public protocol AudioBubbleViewStyleProtocol {
    func bubbleImage(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIImage
    func bubbleImageBorder(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIImage?
    func textFont(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIFont
    func textColor(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIColor
    func textInsets(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIEdgeInsets
}

public final class AudioBubbleView: UIView, MaximumLayoutWidthSpecificable, BackgroundSizingQueryable {
    let audioMessageText: NSAttributedString = NSAttributedString(string: "Voice Message",
                                                                  attributes: [
                                                                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                                                                    NSAttributedString.Key.foregroundColor: UIColor(rgb: 0x8E9094)])
    public var preferredMaxLayoutWidth: CGFloat = 0
    public var animationDuration: CFTimeInterval = 0.33
    public var viewContext: ViewContext = .normal {
        didSet {
            if self.viewContext == .sizing {
                self.textView.dataDetectorTypes = UIDataDetectorTypes()
                self.textView.isSelectable = false
            } else {
                self.textView.dataDetectorTypes = .all
                self.textView.isSelectable = true
            }
        }
    }

    private var displayTime: TimeInterval = 0
    private var playImageView: UIImageView = UIImageView()
    private var buttonWrapperView: UIView = UIView()
    private var helpConstraint: NSLayoutConstraint = NSLayoutConstraint()
    private var timer: Timer?
    
    private let noProgressViewStates: [TransferStatus] = [.idle, .success, .failed]
    
    public private(set) var progressIndicatorView: CircleProgressIndicatorView = {
        return CircleProgressIndicatorView(size: CGSize(width: 33, height: 33))
    }()

    public var style: AudioBubbleViewStyleProtocol! {
        didSet {
            self.updateViews()
        }
    }

    public var audioMessageViewModel: AudioMessageViewModelProtocol! {
        didSet {
            self.updateViews()
        }
    }

    public var selected: Bool = false {
        didSet {
            if self.selected != oldValue {
                self.updateViews()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }

    private func commonInit() {
        self.addSubview(self.bubbleImageView)

        let stackView = UIStackView()
        self.addSubview(stackView)

        self.setupPlayButton(in: stackView)
        self.setupTextView(in: stackView)
        self.setupProgressView(in: stackView)
    }
    
    private func setupProgressView(in stackView: UIStackView) {
        stackView.addSubview(self.progressIndicatorView)
        self.progressIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        
        self.addConstraint(NSLayoutConstraint(item: self.progressIndicatorView,
                                              attribute: .centerX,
                                              relatedBy: .equal,
                                              toItem: self.buttonWrapperView,
                                              attribute: .centerX,
                                              multiplier: 1,
                                              constant: 0))
        
        self.addConstraint(NSLayoutConstraint(item: self.progressIndicatorView,
                                              attribute: .centerY,
                                              relatedBy: .equal,
                                              toItem: self.buttonWrapperView,
                                              attribute: .centerY,
                                              multiplier: 1,
                                              constant: 0))
    }
    
    private func setupTextView(in stackView: UIStackView) {
        stackView.addSubview(self.textView)
        self.textView.translatesAutoresizingMaskIntoConstraints = false

        self.addConstraint(NSLayoutConstraint(item: self.textView,
                                              attribute: .leading,
                                              relatedBy: .equal,
                                              toItem: self.buttonWrapperView,
                                              attribute: .trailing,
                                              multiplier: 1,
                                              constant: -5))
        
        self.addConstraint(NSLayoutConstraint(item: self.textView,
                                              attribute: .centerY,
                                              relatedBy: .equal,
                                              toItem: self,
                                              attribute: .centerY,
                                              multiplier: 1,
                                              constant: 0))
    }
    
    private func setupPlayButton(in stackView: UIStackView) {
        let playImage = UIImage(named: "icon-play", in: Bundle(for: AudioBubbleView.self), compatibleWith: nil)!
        
        self.playImageView = UIImageView(image: playImage)
        self.playImageView.contentMode = .scaleAspectFit
        self.playImageView.translatesAutoresizingMaskIntoConstraints = false

        self.buttonWrapperView = UIView.init(frame: CGRect.zero)
        self.buttonWrapperView.addSubview(self.playImageView)
        self.buttonWrapperView.translatesAutoresizingMaskIntoConstraints = false

        stackView.addSubview(self.buttonWrapperView)
        
        self.helpConstraint = NSLayoutConstraint(item: self.buttonWrapperView,
                                                 attribute: .leading,
                                                 relatedBy: .equal,
                                                 toItem: self,
                                                 attribute: .leading,
                                                 multiplier: 1,
                                                 constant: 0)
        
        self.addConstraint(NSLayoutConstraint(item: self.buttonWrapperView,
                                              attribute: .top,
                                              relatedBy: .equal,
                                              toItem: self,
                                              attribute: .top,
                                              multiplier: 1,
                                              constant: 0))
        
        self.addConstraint(self.helpConstraint)
        
        self.addConstraint(NSLayoutConstraint(item: self.buttonWrapperView,
                                              attribute: .bottom,
                                              relatedBy: .equal,
                                              toItem: self,
                                              attribute: .bottom,
                                              multiplier: 1,
                                              constant: 0))
        
        self.addConstraint(NSLayoutConstraint(item: self.buttonWrapperView,
                                              attribute: .width,
                                              relatedBy: .equal,
                                              toItem: self.buttonWrapperView,
                                              attribute: .height,
                                              multiplier: 1,
                                              constant: 0))

        // Center play image in button wrapper
        self.addConstraint(NSLayoutConstraint(item: self.playImageView,
                                              attribute: .centerX,
                                              relatedBy: .equal,
                                              toItem: buttonWrapperView,
                                              attribute: .centerX,
                                              multiplier: 1,
                                              constant: 0))
        
        self.addConstraint(NSLayoutConstraint(item: self.playImageView,
                                              attribute: .centerY,
                                              relatedBy: .equal,
                                              toItem: buttonWrapperView,
                                              attribute: .centerY,
                                              multiplier: 1,
                                              constant: 0))
    }

    private lazy var bubbleImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.addSubview(self.borderImageView)
        return imageView
    }()

    private var borderImageView: UIImageView = UIImageView()
    private var textView: UITextView = {
        let textView = ChatMessageTextView()
        UIView.performWithoutAnimation({ () -> Void in // fixes iOS 8 blinking when cell appears
            textView.backgroundColor = UIColor.clear
        })
        textView.isEditable = false
        textView.isSelectable = true
        textView.dataDetectorTypes = .all
        textView.scrollsToTop = false
        textView.isScrollEnabled = false
        textView.bounces = false
        textView.bouncesZoom = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.isExclusiveTouch = true
        textView.textContainer.lineFragmentPadding = 0

        return textView
    }()

    public private(set) var isUpdating: Bool = false
    public func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        self.isUpdating = true
        let updateAndRefreshViews = {
            updateClosure()
            self.isUpdating = false
            self.updateViews()
            if animated {
                self.layoutIfNeeded()
            }
        }
        if animated {
            UIView.animate(withDuration: self.animationDuration, animations: updateAndRefreshViews, completion: { (_) -> Void in
                completion?()
            })
        } else {
            updateAndRefreshViews()
        }
    }

    private func updateViews() {
        DispatchQueue.main.async {
            self.updatePlayButtonView()
            self.updateProgressView()
            
            if self.viewContext == .sizing { return }
            if self.isUpdating { return }
            guard let style = self.style else { return }

            self.helpConstraint.constant = self.audioMessageViewModel.isIncoming ? 5 : 0

            self.updateTextView()
            let bubbleImage = style.bubbleImage(viewModel: self.audioMessageViewModel, isSelected: self.selected)
            let borderImage = style.bubbleImageBorder(viewModel: self.audioMessageViewModel, isSelected: self.selected)
            if self.bubbleImageView.image != bubbleImage { self.bubbleImageView.image = bubbleImage }
            if self.borderImageView.image != borderImage { self.borderImageView.image = borderImage }
        }
    }
    
    private func updateProgressView() {
        let transferStatus = self.audioMessageViewModel.transferStatus.value
        let transferProgress = self.audioMessageViewModel.transferProgress.value
        self.progressIndicatorView.isHidden = self.noProgressViewStates.contains(self.audioMessageViewModel.transferStatus.value)
  
        self.progressIndicatorView.progressLineColor = .white
        
        self.progressIndicatorView.progressLineWidth = 1
        self.progressIndicatorView.setProgress(CGFloat(transferProgress))

        switch transferStatus {
        case .idle, .success, .failed:

            break
        case .transfering:
            switch transferProgress {
            case 0:
                if self.progressIndicatorView.progressStatus != .starting { self.progressIndicatorView.progressStatus = .starting }
            case 1:
                if self.progressIndicatorView.progressStatus != .completed { self.progressIndicatorView.progressStatus = .completed }
            default:
                if self.progressIndicatorView.progressStatus != .inProgress { self.progressIndicatorView.progressStatus = .inProgress }
            }
        }
    }
    
    private func updatePlayButtonView() {
        self.playImageView.isHidden = !self.noProgressViewStates.contains(self.audioMessageViewModel.transferStatus.value)
        
        switch self.audioMessageViewModel.state.value {
        case .playing:
            if (self.timer == nil) {
                self.playImageView.image = UIImage(named: "icon-pause", in: Bundle(for: AudioBubbleView.self), compatibleWith: nil)!
                self.timer = Timer.scheduledTimer(timeInterval: 0.01,
                                                  target: self,
                                                  selector: #selector(AudioBubbleView.updateTimer),
                                                  userInfo: nil,
                                                  repeats: true)
                self.updateTimer()
            }
        case .paused:
            self.playImageView.image = UIImage(named: "icon-play", in: Bundle(for: AudioBubbleView.self), compatibleWith: nil)!
            self.stopTimer()
        case .stopped:
            self.playImageView.image = UIImage(named: "icon-play", in: Bundle(for: AudioBubbleView.self), compatibleWith: nil)!
            self.stopTimer()
            self.displayTime = self.audioMessageViewModel.duration + 0.9
        }
    }

    @objc private func updateTimer() {
        defer { self.textView.attributedText = self.formattedDisplayTime }
        
        if self.displayTime < 0 {
            self.displayTime = self.audioMessageViewModel.duration
            self.stopTimer()

            return
        }
        
        self.displayTime -= 0.01
    }

    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }

    private func updateTextView() {
        self.textView.dataDetectorTypes = []
        guard let style = self.style, let viewModel = self.audioMessageViewModel else { return }

        let font = style.textFont(viewModel: viewModel, isSelected: self.selected)
        let textColor = style.textColor(viewModel: viewModel, isSelected: self.selected)

        var needsToUpdateText = false

        if self.textView.font != font {
            self.textView.font = font
            needsToUpdateText = true
        }

        if self.textView.textColor != textColor {
            self.textView.textColor = textColor
            self.textView.linkTextAttributes = convertToOptionalNSAttributedStringKeyDictionary([
                NSAttributedString.Key.foregroundColor.rawValue: textColor,
                NSAttributedString.Key.underlineStyle.rawValue: NSUnderlineStyle.single.rawValue
            ])
            needsToUpdateText = true
        }

        if needsToUpdateText || self.textView.attributedText != self.formattedDisplayTime {
            self.textView.attributedText = self.formattedDisplayTime
        }
    }

    private var formattedDisplayTime: NSMutableAttributedString {
        let time = self.displayTime
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60

        let timerString = "\n" + String(format:"%02i:%02i", minutes, seconds)

        let result = NSMutableAttributedString()
        result.append(self.audioMessageText)
        result.append(NSAttributedString(string: timerString, attributes: [
                                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                                        NSAttributedString.Key.foregroundColor: UIColor.white]))

        return result
    }

    private func bubbleImage() -> UIImage {
        return self.style.bubbleImage(viewModel: self.audioMessageViewModel, isSelected: self.selected)
    }

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.calculateAudioBubbleLayout(preferredMaxLayoutWidth: size.width).size
    }

    // MARK: Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        let layout = self.calculateAudioBubbleLayout(preferredMaxLayoutWidth: self.preferredMaxLayoutWidth)
        self.textView.bma_rect = layout.textFrame
        self.bubbleImageView.bma_rect = layout.bubbleFrame
        self.borderImageView.bma_rect = self.bubbleImageView.bounds
    }

    public var layoutCache: NSCache<AnyObject, AnyObject>!
    private func calculateAudioBubbleLayout(preferredMaxLayoutWidth: CGFloat) -> AudioBubbleLayoutModel {
        let layoutContext = AudioBubbleLayoutModel.LayoutContext(
            text: self.audioMessageText.string,
            font: self.style.textFont(viewModel: self.audioMessageViewModel, isSelected: self.selected),
            textInsets: self.style.textInsets(viewModel: self.audioMessageViewModel, isSelected: self.selected),
            preferredMaxLayoutWidth: preferredMaxLayoutWidth
        )

        if let layoutModel = self.layoutCache.object(forKey: layoutContext.hashValue as AnyObject) as? AudioBubbleLayoutModel, layoutModel.layoutContext == layoutContext {
            return layoutModel
        }

        let layoutModel = AudioBubbleLayoutModel(layoutContext: layoutContext)
        layoutModel.calculateLayout()

        self.layoutCache.setObject(layoutModel, forKey: layoutContext.hashValue as AnyObject)
        return layoutModel
    }

    public var canCalculateSizeInBackground: Bool {
        return true
    }
}

private final class AudioBubbleLayoutModel {
    let layoutContext: LayoutContext
    var textFrame: CGRect = CGRect.zero
    var bubbleFrame: CGRect = CGRect.zero
    var size: CGSize = CGSize.zero

    init(layoutContext: LayoutContext) {
        self.layoutContext = layoutContext
    }

    struct LayoutContext: Equatable, Hashable {
        let text: String
        let font: UIFont
        let textInsets: UIEdgeInsets
        let preferredMaxLayoutWidth: CGFloat

        var hashValue: Int {
            return Chatto.bma_combine(hashes: [self.text.hashValue, self.textInsets.bma_hashValue, self.preferredMaxLayoutWidth.hashValue, self.font.hashValue])
        }

        static func == (lhs: AudioBubbleLayoutModel.LayoutContext, rhs: AudioBubbleLayoutModel.LayoutContext) -> Bool {
            let lhsValues = (lhs.text, lhs.textInsets, lhs.font, lhs.preferredMaxLayoutWidth)
            let rhsValues = (rhs.text, rhs.textInsets, rhs.font, rhs.preferredMaxLayoutWidth)
            return lhsValues == rhsValues
        }
    }

    func calculateLayout() {
        let bubbleSize = CGSize(width: 180, height: 60)
        self.bubbleFrame = CGRect(origin: CGPoint.zero, size: bubbleSize)
        self.size = bubbleSize

        let maxTextWidth_ = CGFloat(10)
        let textSize_ = self.textSizeThatFitsWidth(maxTextWidth_)
        let bubbleSize_ = textSize_.bma_outsetBy(dx: CGFloat(10), dy: 20)
        self.textFrame = CGRect(origin: CGPoint.zero, size: bubbleSize_)
    }

    private func textSizeThatFitsWidth(_ width: CGFloat) -> CGSize {
        let textContainer: NSTextContainer = {
            let size = CGSize(width: width, height: .greatestFiniteMagnitude)
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            return container
        }()

        let textStorage = self.replicateUITextViewNSTextStorage()
        let layoutManager: NSLayoutManager = {
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            return layoutManager
        }()

        let rect = layoutManager.usedRect(for: textContainer)
        return rect.size.bma_round()
    }

    private func replicateUITextViewNSTextStorage() -> NSTextStorage {
        // See https://github.com/badoo/Chatto/issues/129
        return NSTextStorage(string: self.layoutContext.text, attributes: [
            NSAttributedString.Key.font: self.layoutContext.font,
            NSAttributedString.Key(rawValue: "NSOriginalFont"): self.layoutContext.font
            ])
    }
}

/// UITextView with hacks to avoid selection, loupe, define...
private final class ChatMessageTextView: UITextViewZeroPaddings {

    override var canBecomeFirstResponder: Bool {
        return false
    }

    // See https://github.com/badoo/Chatto/issues/363
    override var gestureRecognizers: [UIGestureRecognizer]? {
        set {
            super.gestureRecognizers = newValue
        }
        get {
            return super.gestureRecognizers?.filter({ (gestureRecognizer) -> Bool in
                return type(of: gestureRecognizer) == UILongPressGestureRecognizer.self && gestureRecognizer.delaysTouchesEnded
            })
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }

    override var selectedRange: NSRange {
        get {
            return NSRange(location: 0, length: 0)
        }
        set {
            // Part of the heaviest stack trace when scrolling (when updating text)
            // See https://github.com/badoo/Chatto/pull/144
        }
    }

    override var contentOffset: CGPoint {
        get {
            return .zero
        }
        set {
            // Part of the heaviest stack trace when scrolling (when bounds are set)
            // See https://github.com/badoo/Chatto/pull/144
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
