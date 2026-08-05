# iOS app

SwiftUI and CoreBluetooth client for the controller. It talks the same 4 byte frame the
firmware parses, `[0xC8][brightness][colour][0xFA]`, and re-syncs the sliders on every
connect using the FB FB state query. The other end of the protocol is in
[firmware/main.c](../firmware/main.c#L91).

I designed the BLE protocol, application behaviour, and firmware integration. The SwiftUI/CoreBluetooth implementation was developed with AI assistance, then reviewed and validated against the controller hardware.

