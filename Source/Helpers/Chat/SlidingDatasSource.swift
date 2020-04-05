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

import Foundation

public enum InsertPosition {
    case top
    case bottom
}

public class SlidingDataSource<Element> {
    private var pageSize: Int = ChatConstants.chatPageSize
    private var windowOffset: Int
    private var windowCount: Int
    private(set) var itemGenerator: ((Int, [Message]) -> Element)
    private(set) var items = [Element]()
    private var itemsOffset: Int

    private var allItemsCount: Int {
        return self.items.count + self.itemsOffset
    }

    public var itemsInWindow: [Element] {
        let offset = self.windowOffset - self.itemsOffset
        let a = offset < 0 ? 0 : offset
        var b = a + self.windowCount + abs(offset)
        b = b > items.count ? items.count : b

        return Array(items[a..<b])
    }

    init(count: Int, itemGenerator: @escaping ((Int, [Message]) -> Element)) {
        self.windowOffset = count
        self.itemsOffset = count
        self.windowCount = 0
        self.itemGenerator = itemGenerator

        self.showItems(min(self.pageSize, count), position: .top)
    }

    public func showItems(_ count: Int, position: InsertPosition) {
        guard count > 0 else {
            return
        }

        guard let channel = CoreData.shared.currentChannel else {
            Log.error(CoreData.Error.nilCurrentChannel,
                      message: "Missing current channel to show items for")
            return
        }

        let messages = channel.visibleMessages

        for _ in 0..<count {
            let messageNumber = messages.count - self.items.count - 1
            if messageNumber >= 0 {
                self.insertItem(itemGenerator(messages.count - self.items.count - 1, messages), position: position)
            }
        }
    }

    public func updateMessageList() {
        guard let channel = CoreData.shared.currentChannel else {
            Log.error(CoreData.Error.nilCurrentChannel,
                      message: "Missing current channel to show items for")
            return
        }

        let messages = channel.visibleMessages

        while self.allItemsCount < messages.count {
            self.insertItem(itemGenerator(self.allItemsCount, messages), position: .bottom)
        }
    }
    
    public func updateItems(where selectPredicate: (Element) -> Bool, changePredicate: (Element) throws -> Element) throws {
        self.items = try self.items.map {
            try selectPredicate($0) ? changePredicate($0) : $0
        }
    }

    public func insertItem(_ item: Element, position: InsertPosition) {
        if position == .top {
            self.items.insert(item, at: 0)
            let shouldExpandWindow = self.itemsOffset == self.windowOffset
            self.itemsOffset -= 1
            if shouldExpandWindow {
                self.windowOffset -= 1
                self.windowCount += 1
            }
        } else {
            let shouldExpandWindow = self.allItemsCount == self.windowOffset + self.windowCount
            if shouldExpandWindow {
                self.windowCount += 1
            }
            self.items.append(item)
        }
    }

    public func hasPrevious() -> Bool {
        return self.windowOffset > 0
    }

    public func hasMore() -> Bool {
        return self.windowOffset + self.windowCount < self.allItemsCount
    }

    public func loadPrevious() {
        let previousWindowOffset = self.windowOffset
        let previousWindowCount = self.windowCount
        let nextWindowOffset = max(0, self.windowOffset - self.pageSize)
        let messagesNeeded = self.itemsOffset - nextWindowOffset

        if messagesNeeded > 0 {
            self.showItems(messagesNeeded, position: .top)
        }

        let newItemsCount = previousWindowOffset - nextWindowOffset
        self.windowOffset = nextWindowOffset
        self.windowCount = previousWindowCount + newItemsCount
    }

    public func loadNext() {
        guard !self.items.isEmpty else { return }
        let itemCountAfterWindow = self.allItemsCount - self.windowOffset - self.windowCount
        self.windowCount += min(self.pageSize, itemCountAfterWindow)
    }

    @discardableResult
    public func adjustWindow(focusPosition: Double, maxWindowSize: Int) -> Bool {
        assert(0 <= focusPosition && focusPosition <= 1, "")
        guard 0 <= focusPosition && focusPosition <= 1 else {
            assert(false, "focus should be in the [0, 1] interval")
            return false
        }
        let sizeDiff = self.windowCount - maxWindowSize
        guard sizeDiff > 0 else { return false }
        self.windowOffset += Int(focusPosition * Double(sizeDiff))
        self.windowCount = maxWindowSize
        return true
    }
}
