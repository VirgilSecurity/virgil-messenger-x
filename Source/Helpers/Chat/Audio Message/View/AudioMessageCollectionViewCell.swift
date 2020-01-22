//
//  AudioMessageCollectionViewCell.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/21/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

public typealias AudioMessageCollectionViewCellStyleProtocol = AudioBubbleViewStyleProtocol

public final class AudioMessageCollectionViewCell: BaseMessageCollectionViewCell<AudioBubbleView> {

    public static func sizingCell() -> AudioMessageCollectionViewCell {
        let cell = AudioMessageCollectionViewCell(frame: CGRect.zero)
        cell.viewContext = .sizing
        return cell
    }

    // MARK: Subclassing (view creation)

    public override func createBubbleView() -> AudioBubbleView {
        return AudioBubbleView()
    }

    public override func performBatchUpdates(_ updateClosure: @escaping () -> Void, animated: Bool, completion: (() -> Void)?) {
        super.performBatchUpdates({ () -> Void in
            self.bubbleView.performBatchUpdates(updateClosure, animated: false, completion: nil)
        }, animated: animated, completion: completion)
    }

    // MARK: Property forwarding

    override public var viewContext: ViewContext {
        didSet {
            self.bubbleView.viewContext = self.viewContext
        }
    }

    public var audioMessageViewModel: AudioMessageViewModelProtocol! {
        didSet {
            self.messageViewModel = self.audioMessageViewModel
            self.bubbleView.audioMessageViewModel = self.audioMessageViewModel
        }
    }

    public var textMessageStyle: AudioMessageCollectionViewCellStyleProtocol! {
        didSet {
            self.bubbleView.style = self.textMessageStyle
        }
    }

    override public var isSelected: Bool {
        didSet {
            self.bubbleView.selected = self.isSelected
        }
    }

    public var layoutCache: NSCache<AnyObject, AnyObject>! {
        didSet {
            self.bubbleView.layoutCache = self.layoutCache
        }
    }
}
