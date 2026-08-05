//
//  ShelfController.swift
//  Shady Electronics — LED Shelf Controller
//
//  SwiftUI app for the RNBD350 Transparent UART service.
//  Sends 4-byte frames; on every (re)connect it queries the STM32
//  for current state (C8 FB FB FA) and syncs the sliders:
//
//      [0xC8] [brightness: 0x00–0x28] [colour: 0x00–0x28] [0xFA]
//
//  Setup:
//   1. Xcode -> New Project -> iOS App -> SwiftUI.
//   2. Replace the two generated .swift files with this one.
//   3. Target -> Info -> add key:
//      "Privacy - Bluetooth Always Usage Description" (any text).
//   4. Signing: personal Apple ID team. Run on your iPhone.
//

import SwiftUI
import CoreBluetooth
import Combine

// MARK: - Protocol

enum ShelfProtocol {
    static let startByte: UInt8 = 0xC8
    static let endByte: UInt8  = 0xFA
    static let maxValue: UInt8 = 40   // 0x28 — sliders and frames cap here

    static let serviceUUID = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
    static let writeCharUUID = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    // Module -> phone (Notify) — carries state reports from the STM32
    static let notifyCharUUID = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
    // "Send me your state" sentinel: payload FB FB is outside the legal 0…0x28 range
    static let queryFrame = Data([startByte, 0xFB, 0xFB, endByte])

    static func frame(_ b2: UInt8, _ b3: UInt8) -> Data {
        Data([startByte, min(b2, maxValue), min(b3, maxValue), endByte])
    }
}

// MARK: - BLE (send-only)

final class BLEManager: NSObject, ObservableObject {
    enum ConnectionState: String {
        case bluetoothOff = "Bluetooth off"
        case scanning = "Scanning…"
        case connecting = "Connecting…"
        case ready = "Connected"
        case disconnected = "Disconnected"
    }

    @Published var state: ConnectionState = .disconnected
    @Published var deviceName: String = "—"
    @Published var deviceState: (brightness: UInt8, colour: UInt8)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?

    // Throttle: keep only the newest frame, flush at ~30 Hz if changed.
    private var pendingFrame: Data?
    private var lastSentFrame: Data?
    private var sendTimer: Timer?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        sendTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0,
                                         repeats: true) { [weak self] _ in
            self?.flushPending()
        }
    }

    func startScan() {
        guard central.state == .poweredOn else { return }
        state = .scanning
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    /// Queue newest values; timer sends at most 30 frames/s.
    func send(_ b2: UInt8, _ b3: UInt8) {
        pendingFrame = ShelfProtocol.frame(b2, b3)
    }

    /// Bypass throttle — used when a slider is released so the final
    /// value always lands.
    func sendImmediate(_ b2: UInt8, _ b3: UInt8) {
        pendingFrame = nil
        write(ShelfProtocol.frame(b2, b3))
    }

    private func flushPending() {
        guard let f = pendingFrame, f != lastSentFrame else { return }
        pendingFrame = nil
        write(f)
    }

    private func write(_ data: Data) {
        guard state == .ready, let p = peripheral, let c = writeChar else { return }
        p.writeValue(data, for: c, type: .withoutResponse)
        lastSentFrame = data
    }
}

extension BLEManager: CBCentralManagerDelegate, CBPeripheralDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: startScan()
        case .poweredOff: state = .bluetoothOff
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard (peripheral.name ?? "").hasPrefix("RNBD350") else { return }
        self.peripheral = peripheral
        deviceName = peripheral.name ?? "RNBD350"
        central.stopScan()
        state = .connecting
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([ShelfProtocol.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        state = .disconnected
        writeChar = nil
        self.peripheral = nil
        startScan()   // auto-reconnect
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        state = .disconnected
        startScan()
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let s = peripheral.services?
            .first(where: { $0.uuid == ShelfProtocol.serviceUUID }) else { return }
        peripheral.discoverCharacteristics(
            [ShelfProtocol.writeCharUUID, ShelfProtocol.notifyCharUUID],
            for: s)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for c in service.characteristics ?? [] {
            if c.uuid == ShelfProtocol.writeCharUUID {
                writeChar = c
            } else if c.uuid == ShelfProtocol.notifyCharUUID {
                peripheral.setNotifyValue(true, for: c)   // arm notifications first
            }
        }
        if writeChar != nil {
            state = .ready
            // Runs on every fresh connection = app start AND every reconnect
            peripheral.writeValue(ShelfProtocol.queryFrame,
                                  for: writeChar!, type: .withoutResponse)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        // Validate C8 .. .. FA with legal payload; also drops any echoed query frame
        guard let d = characteristic.value,
              d.count == 4,
              d[0] == ShelfProtocol.startByte,
              d[3] == ShelfProtocol.endByte,
              d[1] <= ShelfProtocol.maxValue,
              d[2] <= ShelfProtocol.maxValue else { return }
        deviceState = (brightness: d[1], colour: d[2])
    }
}

// MARK: - UI

struct ContentView: View {
    @StateObject private var ble = BLEManager()

    // Byte 2 = brightness, byte 3 = colour (both 0…40).
    @State private var brightness: Double = 0   // 0…0x40
    @State private var colour: Double = 0   // 0…0x40

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    HStack {
                        Circle()
                            .fill(ble.state == .ready ? .green : .orange)
                            .frame(width: 10, height: 10)
                        Text(ble.state.rawValue)
                        Spacer()
                        Text(ble.deviceName)
                            .foregroundStyle(.secondary)
                    }
                    if ble.state == .disconnected || ble.state == .bluetoothOff {
                        Button("Scan") { ble.startScan() }
                    } else if ble.state == .ready {
                        Button("Disconnect", role: .destructive) { ble.disconnect() }
                    }
                }

                Section("Brightness") {
                    slider($brightness)
                }
                Section("Colour") {
                    slider($colour)
                }

                Section("Frame") {
                    Text(frameHex)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("LED Shelf")
            .onReceive(ble.$deviceState) { s in
                guard let s else { return }
                brightness = Double(s.brightness)
                colour = Double(s.colour)
            }
        }
    }

    private var frameHex: String {
        ShelfProtocol.frame(UInt8(brightness), UInt8(colour))
            .map { String(format: "%02X", $0) }
            .joined(separator: " ")
    }

    private func slider(_ value: Binding<Double>) -> some View {
        HStack {
            Slider(value: value,
                   in: 0...Double(ShelfProtocol.maxValue),
                   step: 1) { editing in
                if !editing { pushImmediate() }
            }
            .onChange(of: value.wrappedValue) { _, _ in push() }
            Text(String(format: "0x%02X", Int(value.wrappedValue)))
                .font(.system(.body, design: .monospaced))
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func push() {
        ble.send(UInt8(brightness), UInt8(colour))
    }

    private func pushImmediate() {
        ble.sendImmediate(UInt8(brightness), UInt8(colour))
    }
}

@main
struct ShelfControllerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
