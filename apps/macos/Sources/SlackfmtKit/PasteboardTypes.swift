import AppKit

public enum PasteboardTypes {
    public static let customData = NSPasteboard.PasteboardType("org.chromium.web-custom-data")
    public static let slackEntry = "slack/texty"
    public static let images: Set<NSPasteboard.PasteboardType> = [
        .png, .tiff, NSPasteboard.PasteboardType("public.jpeg"), NSPasteboard.PasteboardType("public.heic"),
    ]
}
