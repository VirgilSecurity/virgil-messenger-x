/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import Chatto
import ChattoAdditions
import TwilioChatClient
import AVFoundation
import VirgilSDK

class DataSource: ChatDataSourceProtocol {
    let count: Int
    var nextMessageId: Int = 0
    let preferredMaxWindowSize = 500
    private let pageSize = ChatConstants.chatPageSize
    var slidingWindow: SlidingDataSource<ChatItemProtocol>!

    init(count: Int) {
        self.count = count

        self.slidingWindow = SlidingDataSource(count: count, pageSize: pageSize) { [weak self] (messageNumber, messages) -> ChatItemProtocol in
            self?.nextMessageId += 1
            let id = self?.nextMessageId ?? 0

            guard self != nil,
                let message = messages[safe: messageNumber] else {
                    return MessageFactory.createCorruptedMessageModel(uid: id)
            }

            return message.exportAsUIModel(withId: id)
        }

        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(DataSource.processMessage(notification:)),
                                               name: Notification.Name(rawValue: TwilioHelper.Notifications.MessageAddedToSelectedChannel.rawValue),
                                               object: nil)
    }

    @objc private func processMessage(notification: Notification) {
        DispatchQueue.main.async {
            guard let userInfo = notification.userInfo,
                let message = userInfo[TwilioHelper.NotificationKeys.Message.rawValue] as? Message else {
                    return
            }

            self.nextMessageId += 1
            let uiModel = message.exportAsUIModel(withId: self.nextMessageId)

            self.slidingWindow.insertItem(uiModel, position: .bottom)
            self.delegate?.chatDataSourceDidUpdate(self)
        }
    }

    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.onMessageChanged = { [weak self] message in
            guard let sSelf = self else { return }
            sSelf.delegate?.chatDataSourceDidUpdate(sSelf)
        }
        return sender
    }()

    var hasMoreNext: Bool {
        return self.slidingWindow.hasMore()
    }

    var hasMorePrevious: Bool {
        return self.slidingWindow.hasPrevious()
    }

    var chatItems: [ChatItemProtocol] {
        return self.slidingWindow.itemsInWindow
    }

    weak var delegate: ChatDataSourceDelegateProtocol?

    func loadNext() {
        self.slidingWindow.loadNext()
        self.slidingWindow.adjustWindow(focusPosition: 1, maxWindowSize: self.preferredMaxWindowSize)
        self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination)
    }

    func loadPrevious() {
        self.slidingWindow.loadPrevious()
        self.slidingWindow.adjustWindow(focusPosition: 0, maxWindowSize: self.preferredMaxWindowSize)
        self.delegate?.chatDataSourceDidUpdate(self, updateType: .pagination)
    }

    func addRemoveMemberMessage(remove card: Card) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let text = "\(TwilioHelper.shared.username) removed \(card.identity)"

                guard let twilioChannel = TwilioHelper.shared.currentChannel,
                    let coreChannel = CoreDataHelper.shared.currentChannel else {
                        completion(nil, NSError())
                        return
                }

                CoreDataHelper.shared.remove([card], from: coreChannel)

                guard let session = VirgilHelper.shared.getGroupSession(of: coreChannel) else {
                    completion(nil, nil)
                    return
                }

                let ticket = try session.createChangeMembersTicket(add: [], removeCardIds: [card.identifier])

                let message = try CoreDataHelper.shared.createChangeMembersMessage(text, isIncoming: false)

                let serviceMessage = try ServiceMessage(message: ticket,
                                                        type: .changeMembers,
                                                        members: coreChannel.cards,
                                                        add: [],
                                                        remove: [card])
                let serialized = try serviceMessage.export()

                try VirgilHelper.shared.makeSendServiceMessageOperation(cards: coreChannel.cards, ticket: serialized).startSync().getResult()

                try session.useChangeMembersTicket(ticket: ticket, addCards: [], removeCardIds: [card.identifier])
                try session.sessionStorage.storeSession(session)

                try self.messageSender.sendChangeMembers(message: message).startSync().getResult()

                try TwilioHelper.shared.remove(member: card.identity, from: twilioChannel).startSync().getResult()

                CoreDataHelper.shared.delete(serviceMessage: serviceMessage)

                self.nextMessageId += 1
                let uiModel = message.exportAsUIModel(withId: self.nextMessageId)

                self.slidingWindow.insertItem(uiModel, position: .bottom)

                DispatchQueue.main.async {
                    self.delegate?.chatDataSourceDidUpdate(self)
                    completion((), nil)
                }
            } catch{
                completion(nil, error)
            }
        }
    }

    func addChangeMembersMessage(add cards: [Card]) -> CallbackOperation<Void> {
        return CallbackOperation { _, completion in
            do {
                let members = cards.map { $0.identity }

                guard let first = members.first else {
                    completion(nil, NSError())
                    return
                }

                var text = "\(TwilioHelper.shared.username) added \(first)"

                for member in members {
                    if member != first {
                        text += ", \(member)"
                    }
                }

                guard let twilioChannel = TwilioHelper.shared.currentChannel,
                    let coreChannel = CoreDataHelper.shared.currentChannel else {
                        completion(nil, NSError())
                        return
                }

                let identities = cards.map { $0.identity }

                try TwilioHelper.shared.add(members: identities, to: twilioChannel).startSync().getResult()

                CoreDataHelper.shared.add(cards, to: coreChannel)

                guard let session = VirgilHelper.shared.getGroupSession(of: coreChannel) else {
                    completion(nil, nil)
                    return
                }

                let ticket = try session.createChangeMembersTicket(add: cards, removeCardIds: [])

                let message = try CoreDataHelper.shared.createChangeMembersMessage(text, isIncoming: false)

                let serviceMessage = try ServiceMessage(message: ticket,
                                                        type: .changeMembers,
                                                        members: coreChannel.cards,
                                                        add: cards,
                                                        remove: [])
                let serialized = try serviceMessage.export()

                try VirgilHelper.shared.makeSendServiceMessageOperation(cards: coreChannel.cards, ticket: serialized).startSync().getResult()

                try session.useChangeMembersTicket(ticket: ticket, addCards: cards, removeCardIds: [])
                try session.sessionStorage.storeSession(session)

                try self.messageSender.sendChangeMembers(message: message).startSync().getResult()

                CoreDataHelper.shared.delete(serviceMessage: serviceMessage)

                self.nextMessageId += 1
                let uiModel = message.exportAsUIModel(withId: self.nextMessageId)

                self.slidingWindow.insertItem(uiModel, position: .bottom)

                DispatchQueue.main.async {
                    self.delegate?.chatDataSourceDidUpdate(self)
                    completion((), nil)
                }
            } catch {
                completion(nil, error)
            }
        }
    }

    func addTextMessage(_ text: String) throws {
        let message = try CoreDataHelper.shared.createTextMessage(text, isIncoming: false)

        self.nextMessageId += 1
        let id = self.nextMessageId

        let uiModel = try self.messageSender.send(message: message, withId: id)

        self.slidingWindow.insertItem(uiModel, position: .bottom)
        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addPhotoMessage(_ image: UIImage) {
        // TODO
//        self.nextMessageId += 1
//        let id = self.nextMessageId
//        let message = MessageFactory.createPhotoMessageModel(uid: id,
//                                                             image: image,
//                                                             size: image.size,
//                                                             isIncoming: false,
//                                                             status: .sending)
//        self.messageSender.sendMessage(message, type: .regular)
//        self.slidingWindow.insertItem(message, position: .bottom)
//        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func addAudioMessage(_ audio: Data) {
        // TODO
//        self.nextMessageId += 1
//        let id = self.nextMessageId
//
//        let message: DemoMessageModelProtocol
//
//        // FIXME
//        if let duration = try? AVAudioPlayer(data: audio).duration {
//            message = MessageFactory.createAudioMessageModel(uid: id,
//                                                             audio: audio,
//                                                             duration: duration,
//                                                             isIncoming: false,
//                                                             status: .sending)
//        } else {
//            Log.error("Getting audio duration failed")
//            message = MessageFactory.createCorruptedMessageModel(uid: id)
//            return
//        }
//
//        self.messageSender.sendMessage(message, type: .regular)
//        self.slidingWindow.insertItem(message, position: .bottom)
//        self.delegate?.chatDataSourceDidUpdate(self)
    }

    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> ()) {
        let didAdjust = self.slidingWindow.adjustWindow(focusPosition: focusPosition, maxWindowSize: preferredMaxCount ?? self.preferredMaxWindowSize)
        completion(didAdjust)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
