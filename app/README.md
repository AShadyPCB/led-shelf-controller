# iOS app

SwiftUI and CoreBluetooth client for the controller. It talks the same 4 byte frame the
firmware parses, `[0xC8][brightness][colour][0xFA]`, and re-syncs the sliders on every
connect using the FB FB state query. The other end of the protocol is in
[firmware/main.c](../firmware/main.c#L91).

I designed the protocol and the app's behaviour. The Swift implementation is AI assisted,
I wasn't going to learn iOS to build a remote control. Xcode setup steps are in the header
of [ShelfController.swift](ShelfController.swift).
