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

public class UITextMessageModel: TextMessageModel<MessageModel>, UIMessageModelProtocol {

    public required init(uid: String,
                         text: String,
                         isIncoming: Bool,
                         status: MessageStatus,
                         date: Date
                         /* avatar: UIImage */) {
        self.body = text
//        self.avatar = avatar

        let senderId = isIncoming ? "1" : "2"

        let messageModel = MessageModel(uid: uid,
                                        senderId: senderId,
                                        type: TextMessageModel<MessageModel>.chatItemType,
                                        isIncoming: isIncoming,
                                        date: date,
                                        status: status)

        super.init(messageModel: messageModel, text: text)
    }

    static func corruptedModel(uid: String, isIncoming: Bool = false, date: Date = Date() /* avatar: UIImage */) -> UITextMessageModel {
        return self.init(uid: uid,
                         text: "Corrupted Message",
                         isIncoming: isIncoming,
                         status: .failed,
                         date: date
                         /* avatar: avatar */)
    }

    private(set) var body: String

//    private(set) var avatar: UIImage

    public var status: MessageStatus {
        get {
            return self._messageModel.status
        }
        set {
            self._messageModel.status = newValue
        }
    }
}

extension TextMessageModel {
    static var chatItemType: ChatItemType {
        return "text"
    }
}
