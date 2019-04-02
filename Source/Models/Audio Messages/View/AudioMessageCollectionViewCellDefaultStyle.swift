//
//  AudioMessageCollectionViewCellDefaultStyle.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/21/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import Chatto
import ChattoAdditions

open class AudioMessageCollectionViewCellDefaultStyle: AudioBubbleViewStyleProtocol {
    public typealias Class = AudioMessageCollectionViewCellDefaultStyle

    public struct BubbleImages {
        let incomingTail: () -> UIImage
        let incomingNoTail: () -> UIImage
        let outgoingTail: () -> UIImage
        let outgoingNoTail: () -> UIImage
        public init(
            incomingTail: @autoclosure @escaping () -> UIImage,
            incomingNoTail: @autoclosure @escaping () -> UIImage,
            outgoingTail: @autoclosure @escaping () -> UIImage,
            outgoingNoTail: @autoclosure @escaping () -> UIImage) {
            self.incomingTail = incomingTail
            self.incomingNoTail = incomingNoTail
            self.outgoingTail = outgoingTail
            self.outgoingNoTail = outgoingNoTail
        }
    }

    public struct TextStyle {
        let font: () -> UIFont
        let incomingColor: () -> UIColor
        let outgoingColor: () -> UIColor
        let incomingInsets: UIEdgeInsets
        let outgoingInsets: UIEdgeInsets
        public init(
            font: @autoclosure @escaping () -> UIFont,
            incomingColor: @autoclosure @escaping () -> UIColor,
            outgoingColor: @autoclosure @escaping () -> UIColor,
            incomingInsets: UIEdgeInsets,
            outgoingInsets: UIEdgeInsets) {
            self.font = font
            self.incomingColor = incomingColor
            self.outgoingColor = outgoingColor
            self.incomingInsets = incomingInsets
            self.outgoingInsets = outgoingInsets
        }
    }

    public let bubbleImages: BubbleImages
    public let baseStyle: BaseMessageCollectionViewCellDefaultStyle
    public let textStyle: TextStyle
    lazy var font: UIFont = self.textStyle.font()
    lazy var incomingColor: UIColor = self.textStyle.incomingColor()
    lazy var outgoingColor: UIColor = self.textStyle.outgoingColor()

    public init (
        bubbleImages: BubbleImages = Class.createDefaultBubbleImages(),
        textStyle: TextStyle = Class.createDefaultTextStyle(),
        baseStyle: BaseMessageCollectionViewCellDefaultStyle = BaseMessageCollectionViewCellDefaultStyle()) {
        self.bubbleImages = bubbleImages
        self.textStyle = textStyle
        self.baseStyle = baseStyle
    }

    lazy private var images: [ImageKey: UIImage] = {
        return [
            .template(isIncoming: true, showsTail: true): self.bubbleImages.incomingTail(),
            .template(isIncoming: true, showsTail: false): self.bubbleImages.incomingNoTail(),
            .template(isIncoming: false, showsTail: true): self.bubbleImages.outgoingTail(),
            .template(isIncoming: false, showsTail: false): self.bubbleImages.outgoingNoTail()
        ]
    }()

    public func bubbleImage(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIImage {
        let key = ImageKey.normal(isIncoming: viewModel.isIncoming, status: viewModel.status, showsTail: viewModel.decorationAttributes.isShowingTail, isSelected: isSelected)

        if let image = self.images[key] {
            return image
        } else {
            let templateKey = ImageKey.template(isIncoming: viewModel.isIncoming, showsTail: viewModel.decorationAttributes.isShowingTail)
            if let image = self.images[templateKey] {
                let image = self.createImage(templateImage: image, isIncoming: viewModel.isIncoming, status: viewModel.status, isSelected: isSelected)
                self.images[key] = image
                return image
            }
        }

        assert(false, "coulnd't find image for this status. ImageKey: \(key)")
        return UIImage()
    }

    open func createImage(templateImage image: UIImage, isIncoming: Bool, status: MessageViewModelStatus, isSelected: Bool) -> UIImage {
        var color = isIncoming ? self.baseStyle.baseColorIncoming : self.baseStyle.baseColorOutgoing

        switch status {
        case .success:
            break
        case .failed, .sending:
            color = color.bma_blendWithColor(UIColor.white.withAlphaComponent(0.70))
        }

        if isSelected {
            color = color.bma_blendWithColor(UIColor.black.withAlphaComponent(0.10))
        }

        return image.bma_tintWithColor(color)
    }

    public func bubbleImageBorder(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIImage? {
        return self.baseStyle.borderImage(viewModel: viewModel)
    }

    public func textFont(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIFont {
        return self.font
    }

    public func textColor(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIColor {
        return viewModel.isIncoming ? self.incomingColor : self.outgoingColor
    }

    public func textInsets(viewModel: AudioMessageViewModelProtocol, isSelected: Bool) -> UIEdgeInsets {
        return viewModel.isIncoming ? self.textStyle.incomingInsets : self.textStyle.outgoingInsets
    }

    private enum ImageKey: Hashable {
        case template(isIncoming: Bool, showsTail: Bool)
        case normal(isIncoming: Bool, status: MessageViewModelStatus, showsTail: Bool, isSelected: Bool)

        var hashValue: Int {
            switch self {
            case let .template(isIncoming: isIncoming, showsTail: showsTail):
                return Chatto.bma_combine(hashes: [1 /*template*/, isIncoming.hashValue, showsTail.hashValue])
            case let .normal(isIncoming: isIncoming, status: status, showsTail: showsTail, isSelected: isSelected):
                return Chatto.bma_combine(hashes: [2 /*normal*/, isIncoming.hashValue, status.hashValue, showsTail.hashValue, isSelected.hashValue])
            }
        }

        static func == (lhs: AudioMessageCollectionViewCellDefaultStyle.ImageKey,
                        rhs: AudioMessageCollectionViewCellDefaultStyle.ImageKey) -> Bool {
            switch (lhs, rhs) {
            case let (.template(lhsValues), .template(rhsValues)):
                return lhsValues == rhsValues
            case let (.normal(lhsValues), .normal(rhsValues)):
                return lhsValues == rhsValues
            default:
                return false
            }
        }
    }
}

public extension AudioMessageCollectionViewCellDefaultStyle { // Default values
    static func createDefaultBubbleImages() -> BubbleImages {
        return BubbleImages(
            incomingTail: UIImage(named: "bubble-incoming-tail",
                                  in: Bundle(for: TextMessageCollectionViewCellDefaultStyle.self),
                                  compatibleWith: nil)!,
            incomingNoTail: UIImage(named: "bubble-incoming",
                                    in: Bundle(for: TextMessageCollectionViewCellDefaultStyle.self),
                                    compatibleWith: nil)!,
            outgoingTail: UIImage(named: "bubble-outgoing-tail",
                                  in: Bundle(for: TextMessageCollectionViewCellDefaultStyle.self),
                                  compatibleWith: nil)!,
            outgoingNoTail: UIImage(named: "bubble-outgoing",
                                    in: Bundle(for: TextMessageCollectionViewCellDefaultStyle.self),
                                    compatibleWith: nil)!
        )
    }

    static func createDefaultTextStyle() -> TextStyle {
        return TextStyle(
            font: UIFont.systemFont(ofSize: 16),
            incomingColor: UIColor.black,
            outgoingColor: UIColor.white,
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )
    }
}
