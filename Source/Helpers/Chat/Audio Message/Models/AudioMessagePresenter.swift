//
//  AudioMessagePresenter.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 5/21/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import ChattoAdditions

open class AudioMessagePresenter<ViewModelBuilderT, InteractionHandlerT>
    : BaseMessagePresenter<AudioBubbleView, ViewModelBuilderT, InteractionHandlerT> where
    ViewModelBuilderT: ViewModelBuilderProtocol,
    ViewModelBuilderT.ViewModelT: AudioMessageViewModelProtocol,
    InteractionHandlerT: BaseMessageInteractionHandlerProtocol,
    InteractionHandlerT.ViewModelT == ViewModelBuilderT.ViewModelT {
    public typealias ModelT = ViewModelBuilderT.ModelT
    public typealias ViewModelT = ViewModelBuilderT.ViewModelT

    public init (
        messageModel: ModelT,
        viewModelBuilder: ViewModelBuilderT,
        interactionHandler: InteractionHandlerT?,
        sizingCell: AudioMessageCollectionViewCell,
        baseCellStyle: BaseMessageCollectionViewCellStyleProtocol,
        textCellStyle: AudioMessageCollectionViewCellStyleProtocol,
        layoutCache: NSCache<AnyObject, AnyObject>) {
        self.layoutCache = layoutCache
        self.textCellStyle = textCellStyle
        super.init(
            messageModel: messageModel,
            viewModelBuilder: viewModelBuilder,
            interactionHandler: interactionHandler,
            sizingCell: sizingCell,
            cellStyle: baseCellStyle
        )
    }

    let layoutCache: NSCache<AnyObject, AnyObject>
    let textCellStyle: AudioMessageCollectionViewCellStyleProtocol

    public final override class func registerCells(_ collectionView: UICollectionView) {
        collectionView.register(AudioMessageCollectionViewCell.self, forCellWithReuseIdentifier: "audio-message-incoming")
        collectionView.register(AudioMessageCollectionViewCell.self, forCellWithReuseIdentifier: "audio-message-outcoming")
    }

    public final override func dequeueCell(collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = self.messageViewModel.isIncoming ? "audio-message-incoming" : "audio-message-outcoming"
        return collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
    }

    open override func createViewModel() -> ViewModelBuilderT.ViewModelT {
        let viewModel = self.viewModelBuilder.createViewModel(self.messageModel)
        let updateClosure = { [weak self] (old: Any, new: Any) -> Void in
            self?.updateCurrentCell()
        }
        viewModel.avatarImage.observe(self, closure: updateClosure)
        viewModel.state.observe(self, closure: updateClosure)
        viewModel.transferDirection.observe(self, closure: updateClosure)
        viewModel.transferProgress.observe(self, closure: updateClosure)
        viewModel.transferStatus.observe(self, closure: updateClosure)
        
        return viewModel
    }

    public var textCell: AudioMessageCollectionViewCell? {
        if let cell = self.cell {
            if let textCell = cell as? AudioMessageCollectionViewCell {
                return textCell
            } else {
                assert(false, "Invalid cell was given to presenter!")
            }
        }
        return nil
    }

    open override func configureCell(_ cell: BaseMessageCollectionViewCell<AudioBubbleView>, decorationAttributes: ChatItemDecorationAttributes, animated: Bool, additionalConfiguration: (() -> Void)?) {
        guard let cell = cell as? AudioMessageCollectionViewCell else {
            assert(false, "Invalid cell received")
            return
        }

        super.configureCell(cell, decorationAttributes: decorationAttributes, animated: animated) { () -> Void in
            cell.layoutCache = self.layoutCache
            cell.audioMessageViewModel = self.messageViewModel
            cell.textMessageStyle = self.textCellStyle
            additionalConfiguration?()
        }
    }

    public func updateCurrentCell() {
        if let cell = self.textCell, let decorationAttributes = self.decorationAttributes {
            self.configureCell(cell, decorationAttributes: decorationAttributes,
                               animated: self.itemVisibility != .appearing,
                               additionalConfiguration: nil)
        }
    }

    open override func canShowMenu() -> Bool {
        return true
    }

    open override func canPerformMenuControllerAction(_ action: Selector) -> Bool {
        let selector = #selector(UIResponderStandardEditActions.copy(_:))
        return action == selector
    }
}
