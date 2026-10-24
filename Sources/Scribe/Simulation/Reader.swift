import AppKit
import SwiftUI

/// 원고 읽기 창. 지금까지 쓴 부분만 보여 준다. 원문이 길어서 `NSTextView` 로 그린다.
@MainActor
final class ReaderWindow {
    static let shared = ReaderWindow()
    private var window: NSWindow?

    func show(book: Book, count: Int) {
        let text = Library.prefix(of: book, count: count)
        let view = ReaderView(book: book, count: count, text: text)
        if let window {
            window.contentView = NSHostingView(rootView: view)
            window.title = "\(book.displayTitle) · 원고"
        } else {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 720),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "\(book.displayTitle) · 원고"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            window.setFrameAutosaveName("Reader")
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct ReaderView: View {
    let book: Book
    let count: Int
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                PortraitFrame(author: book.authorShort, scale: 2.25)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.displayTitle).font(.headline)
                    Text("\(book.displayAuthor) · \(book.title)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Format.integer(count)) / \(Format.integer(book.characters))자")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(16)
            Divider()
            ManuscriptScroll(text: text, preserveLines: book.preserveLines)
        }
        .frame(minWidth: 420, minHeight: 400)
    }
}

/// 긴 원문을 스크롤해 읽는 `NSTextView`. 끝(지금 쓰는 자리)으로 열린다.
private struct ManuscriptScroll: NSViewRepresentable {
    let text: String
    let preserveLines: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.isEditable = false
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.font = NSFont(descriptor: NSFont.systemFont(ofSize: 15).fontDescriptor.withDesign(.serif) ?? NSFont.systemFont(ofSize: 15).fontDescriptor, size: 15)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        style.paragraphSpacing = preserveLines ? 0 : 10
        textView.defaultParagraphStyle = style
        textView.typingAttributes = [.paragraphStyle: style, .font: textView.font!, .foregroundColor: NSColor.labelColor]
        apply(text, to: textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView, textView.string != text else { return }
        apply(text, to: textView)
    }

    private func apply(_ text: String, to textView: NSTextView) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textView.font ?? NSFont.systemFont(ofSize: 15),
            .paragraphStyle: textView.defaultParagraphStyle ?? NSParagraphStyle.default,
            .foregroundColor: NSColor.labelColor,
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: attributes))
        textView.scrollToEndOfDocument(nil)
    }
}
