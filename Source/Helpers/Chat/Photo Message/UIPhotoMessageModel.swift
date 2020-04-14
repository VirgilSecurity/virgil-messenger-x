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

public class UIPhotoMessageModel: PhotoMessageModel<MessageModel>, UIMessageModelProtocol {
    public private(set) var state: MediaMessageState
    public private(set) weak var loadDelegate: LoadDelegate?

    public required init(uid: String,
                         image: UIImage,
                         isIncoming: Bool,
                         status: MessageStatus,
                         state: MediaMessageState,
                         date: Date) {
        let senderId = isIncoming ? "1" : "2"

        let messageModel = MessageModel(uid: uid,
                                        senderId: senderId,
                                        type: PhotoMessageModel<MessageModel>.chatItemType,
                                        isIncoming: isIncoming,
                                        date: date,
                                        status: status)

        self.state = state

        super.init(messageModel: messageModel, imageSize: image.size, image: image)
    }

    public var status: MessageStatus {
        get {
            return self._messageModel.status
        }
        set {
            self._messageModel.status = newValue
        }
    }

    public func set(loadDelegate: LoadDelegate) {
        self.loadDelegate = loadDelegate
    }
}

extension UIPhotoMessageModel: LoadDelegate {
    public func progressChanged(to percent: Double) {
        self.loadDelegate?.progressChanged(to: percent)
    }

    public func failed(with error: Error) {
        self.loadDelegate?.failed(with: error)
    }

    public func completed(dataHash: String) {
        self.loadDelegate?.completed(dataHash: dataHash)
    }
}

extension PhotoMessageModel {
    static var chatItemType: ChatItemType {
        return "photo"
    }
}
