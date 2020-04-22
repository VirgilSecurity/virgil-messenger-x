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

import ChattoAdditions

class UIPhotoMessageViewModel: PhotoMessageViewModel<UIPhotoMessageModel> {
    private var imageInProgress: UIImage?
    private var state: MediaMessageState

    override init(photoMessage: UIPhotoMessageModel, messageViewModel: MessageViewModelProtocol) {
        self.state = photoMessage.state

        switch photoMessage.state {
        case .downloading, .uploading:
            self.imageInProgress = photoMessage.image

            super.init(photoMessage: photoMessage, messageViewModel: messageViewModel)

            self.transferStatus.value = .transfering
            photoMessage.set(loadDelegate: self)
        case .normal:
            self.imageInProgress = nil

            super.init(photoMessage: photoMessage, messageViewModel: messageViewModel)
        }
    }
}

extension UIPhotoMessageViewModel: LoadDelegate {
    func progressChanged(to percent: Double) {
        DispatchQueue.main.async {
            guard self.transferStatus.value == .transfering else {
                // TODO: add error logs
                return
            }
            guard percent < 100 else {
                self.transferStatus.value = .success
                return
            }

            self.transferProgress.value = percent
        }
    }

    func failed(with error: Error) {
        DispatchQueue.main.async {
            self.transferStatus.value = .failed
            self.state = .normal
        }
    }

    func completed(dataHash: String) {
        do {
            switch self.state {
            case .downloading:
                let path = try Storage.shared.getMediaStorage().getPath(name: dataHash, type: .photo)

                guard let fullImage = UIImage(contentsOfFile: path) else {
                    throw FileMediaStorage.Error.imageFromFileFailed
                }

                DispatchQueue.main.async {
                    self.image.value = fullImage
                }
            case .uploading, .normal:
                break
            }

            // TODO: remove copypaste
            DispatchQueue.main.async {
                self.transferStatus.value = .success
                self.state = .normal
            }
        }
        catch {
            Log.error(error, message: "Image loading completion failed")

            DispatchQueue.main.async {
                self.transferStatus.value = .failed
                self.state = .normal
            }
        }
    }
}

extension UIPhotoMessageViewModel: UIMessageViewModelProtocol {
    var messageModel: UIMessageModelProtocol {
        return self._photoMessage
    }
}

class UIPhotoMessageViewModelBuilder: ViewModelBuilderProtocol {

    let messageViewModelBuilder = MessageViewModelDefaultBuilder()

    func createViewModel(_ model: UIPhotoMessageModel) -> UIPhotoMessageViewModel {
        let messageViewModel = self.messageViewModelBuilder.createMessageViewModel(model)

        let photoMessageViewModel = UIPhotoMessageViewModel(photoMessage: model, messageViewModel: messageViewModel)
        photoMessageViewModel.avatarImage.value = UIImage(named: "userAvatar")

        return photoMessageViewModel
    }

    func canCreateViewModel(fromModel model: Any) -> Bool {
        return model is UIPhotoMessageModel
    }
}
