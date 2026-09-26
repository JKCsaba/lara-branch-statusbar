//
//  RemoteView.swift
//  lara
//
//  Created by ruter on 17.04.26.
//

import SwiftUI
import Darwin

// V6 keeps the proven V3 status-bar transform and only automates the already-
// verified manual Sync action.  The polling lives in Lara instead of installing
// private UIKit method overrides into SpringBoard.  Lara's existing audio
// keepalive allows this to continue while the app is in the background.
//
// The flag is intentionally module-global so lara.swift can avoid destroying
// the SpringBoard RemoteCall session while auto-follow owns it.
var laraStatusBarAutoFollowActive = false

final class StatusBarAutoFollower {
    static let shared = StatusBarAutoFollower()

    // LOCKED V6 geometry: the successful on-device transform path remains
    // sync_v6_status_bar_to_active_orientation(..., force: 1). V6.1 only makes
    // the *trigger* lighter: one cached orientation read per tick, and the
    // transform runs only after a real orientation change.
    private let queue = DispatchQueue(label: "lara.statusbar.v6.autofollow", qos: .userInteractive)
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var externalActionRunning = false
    private var ownsKeepAlive = false
    private var lastError: Int32 = 0
    private var lastOrientation: UInt64 = 0
    private var invalidOrientationStreak = 0

    // Optional Home Screen accessories. They piggy-back on the same orientation
    // event and therefore add zero extra steady-state polling.
    private var dockLiftEnabled = false
    private var dockLiftPoints: Double = 22.0
    private var bottomGradientEnabled = false
    private var bottomGradientHeight: Double = 100.0

    private init() {}

    var isActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return laraStatusBarAutoFollowActive
    }

    func setExternalActionRunning(_ value: Bool) {
        lock.lock()
        externalActionRunning = value
        lock.unlock()
    }

    private func shouldPoll() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return laraStatusBarAutoFollowActive && !externalActionRunning
    }

    private func ensureKeepAlive() {
        let work = {
            if !kaenabled {
                toggleka()
                self.ownsKeepAlive = kaenabled
            }
        }
        if Thread.isMainThread { work() }
        else { DispatchQueue.main.sync(execute: work) }
    }

    private func accessorySnapshot() -> (dock: Bool, lift: Double, gradient: Bool, gradientHeight: Double) {
        lock.lock(); defer { lock.unlock() }
        return (dockLiftEnabled, dockLiftPoints, bottomGradientEnabled, bottomGradientHeight)
    }

    private func applyAccessories(proc: RemoteCall, orientation: UInt64, mgr: laramgr) {
        let state = accessorySnapshot()
        let upsideDown = orientation == 2

        if state.dock {
            let r = set_v61_dock_vertical_lift(proc, state.lift, upsideDown ? 1 : 0)
            if r != 0 { mgr.logmsg("(rc) V6.1 dock lift -> \(r)") }
        }

        if state.gradient {
            let r = set_v61_bottom_gradient(proc, state.gradientHeight, upsideDown ? 1 : 0)
            if r != 0 { mgr.logmsg("(rc) V6.1 bottom gradient -> \(r)") }
        }
    }

    private func syncChangedOrientation(mgr: laramgr, proc: RemoteCall, orientation: UInt64) {
        let r = sync_v6_status_bar_to_active_orientation(proc, 1)
        if r < 0 {
            lock.lock()
            let shouldLog = lastError != r
            lastError = r
            lock.unlock()
            if shouldLog { mgr.logmsg("(rc) V6 auto-follow sync error -> \(r)") }
            return
        }

        lock.lock()
        lastOrientation = orientation
        lastError = 0
        invalidOrientationStreak = 0
        lock.unlock()

        applyAccessories(proc: proc, orientation: orientation, mgr: mgr)
        mgr.logmsg("(rc) V6 auto-follow: orientation change applied")
    }

    func start(mgr: laramgr) -> String {
        guard mgr.rcready, let proc = mgr.sbProc else {
            return "V6 safe auto-follow: RemoteCall is not ready"
        }

        // This is the same one-tap base that is already proven perfect on-device.
        let base = enable_v6_safe_status_bar_autofollow_base(proc)
        guard base == 0 else {
            return "enable_v6_safe_status_bar_autofollow_base() -> \(base)"
        }

        ensureKeepAlive()

        let initialOrientation = UInt64(get_v6_active_interface_orientation(proc))

        lock.lock()
        laraStatusBarAutoFollowActive = true
        lastError = 0
        invalidOrientationStreak = 0
        lastOrientation = (initialOrientation == 1 || initialOrientation == 2) ? initialOrientation : 0
        let alreadyRunning = (timer != nil)
        lock.unlock()

        if initialOrientation == 1 || initialOrientation == 2 {
            applyAccessories(proc: proc, orientation: initialOrientation, mgr: mgr)
        }

        if !alreadyRunning {
            let t = DispatchSource.makeTimerSource(queue: queue)
            // 400 ms keeps the same "instant" feel while the cached C helper
            // reduces steady-state work to one remote objc_msgSend per tick.
            t.schedule(deadline: .now() + .milliseconds(250),
                       repeating: .milliseconds(400),
                       leeway: .milliseconds(80))
            t.setEventHandler { [weak self, weak mgr] in
                guard let self, let mgr else { return }
                guard self.shouldPoll(), mgr.rcready, let proc = mgr.sbProc else { return }

                let orientation = UInt64(get_v6_active_interface_orientation(proc))
                guard orientation == 1 || orientation == 2 else {
                    self.lock.lock()
                    self.invalidOrientationStreak += 1
                    let streak = self.invalidOrientationStreak
                    self.lock.unlock()
                    // Avoid log spam. A persistent invalid state normally means
                    // SpringBoard/RemoteCall changed underneath us; stop touching it.
                    if streak == 5 {
                        mgr.logmsg("(rc) V6.1 auto-follow: orientation unavailable 5x; transforms skipped")
                    }
                    return
                }

                self.lock.lock()
                let previous = self.lastOrientation
                self.invalidOrientationStreak = 0
                self.lock.unlock()
                guard orientation != previous else { return }

                self.syncChangedOrientation(mgr: mgr, proc: proc, orientation: orientation)
            }

            lock.lock()
            timer = t
            lock.unlock()
            t.resume()
        }

        return "V6 safe auto-follow ACTIVE (locked V3 geometry, cached 400ms trigger, keepalive=\(kaenabled))"
    }

    func forceSync(mgr: laramgr) {
        guard isActive, mgr.rcready, let proc = mgr.sbProc else { return }
        queue.async {
            let orientation = UInt64(get_v6_active_interface_orientation(proc))
            guard orientation == 1 || orientation == 2 else { return }
            self.syncChangedOrientation(mgr: mgr, proc: proc, orientation: orientation)
        }
    }

    func configureDockLift(enabled: Bool, points: Double, mgr: laramgr) -> String {
        let clamped = min(max(abs(points), 0.0), 40.0)
        lock.lock()
        dockLiftEnabled = enabled
        dockLiftPoints = clamped
        lock.unlock()

        guard mgr.rcready, let proc = mgr.sbProc else {
            return "V6.1 dock lift saved; RemoteCall not ready"
        }
        queue.async {
            let orientation = UInt64(get_v6_active_interface_orientation(proc))
            let upsideDown = enabled && orientation == 2
            let r = set_v61_dock_vertical_lift(proc, clamped, upsideDown ? 1 : 0)
            if r != 0 { mgr.logmsg("(rc) V6.1 dock lift immediate -> \(r)") }
        }
        return enabled ? "V6.1 dock lift enabled at \(Int(clamped.rounded())) pt" : "V6.1 dock lift disabled; restoring stock Y"
    }

    func configureBottomGradient(enabled: Bool, height: Double, mgr: laramgr) -> String {
        let clamped = min(max(height, 40.0), 180.0)
        lock.lock()
        bottomGradientEnabled = enabled
        bottomGradientHeight = clamped
        lock.unlock()

        guard mgr.rcready, let proc = mgr.sbProc else {
            return "V6.1 gradient saved; RemoteCall not ready"
        }
        queue.async {
            let orientation = UInt64(get_v6_active_interface_orientation(proc))
            let visible = enabled && orientation == 2
            let r = set_v61_bottom_gradient(proc, clamped, visible ? 1 : 0)
            if r != 0 { mgr.logmsg("(rc) V6.1 gradient immediate -> \(r)") }
        }
        return enabled ? "V6.1 bottom gradient enabled (\(Int(clamped.rounded())) pt)" : "V6.1 bottom gradient disabled"
    }

    func stop() -> String {
        lock.lock()
        laraStatusBarAutoFollowActive = false
        let oldTimer = timer
        timer = nil
        let disableOwnedKeepAlive = ownsKeepAlive
        ownsKeepAlive = false
        lastOrientation = 0
        invalidOrientationStreak = 0
        lock.unlock()

        oldTimer?.setEventHandler {}
        oldTimer?.cancel()

        if disableOwnedKeepAlive {
            let work = { if kaenabled { toggleka() } }
            if Thread.isMainThread { work() }
            else { DispatchQueue.main.sync(execute: work) }
        }

        return "V6 safe auto-follow stopped; current status-bar transform left unchanged"
    }
}

struct RemoteView: View {
    @ObservedObject var mgr: laramgr
    @State private var statusBarTimeFormat: String = "HH:mm"
    @State private var running: Bool = false
    @State private var columns: Int = 5
    @State private var performanceHUD: Int = -1
    @AppStorage("rcdockunlimited") private var rcdockunlimited: Bool = false
    @State private var customProcessName: String = "SpringBoard"
    @State private var customFunctionName: String = "getpid"
    @State private var customArgsText: String = ""
    @State private var customTimeoutMs: Int = 100
    @State private var customMigBypass: Bool = false
    @State private var customLastResult: String = ""
    @State private var hsRows: Int = 6
    @State private var hsColumns: Int = 4
    @State private var freakyrunning: Bool = false
    @State private var freakyseq: Int = 0
    @State private var dockLiftPoints: Double = 22.0
    @State private var dockLiftEnabled: Bool = false
    @State private var bottomGradientHeight: Double = 100.0
    @State private var bottomGradientEnabled: Bool = false

    private var dockMaxColumns: Int { rcdockunlimited ? 50 : 10 }

    var body: some View {
        List {
            Section {
                TextField("Date format (e.g. HH:mm)", text: $statusBarTimeFormat)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    run("Status Bar Time Format") {
                        status_bar_time_format(mgr.sbProc, statusBarTimeFormat)
                        return "status_bar_time_format() done"
                    }
                } label: {
                    Text("Apply")
                }
            } header: {
                Text("Status Bar Time Format")
            } footer: {
                Text("The text automatically updates every MINUTE")
            }

            Section {
                Button {
                    run("Hide Icon Labels") {
                        let hidden = hide_icon_labels(mgr.sbProc)
                        return "hide_icon_labels() -> \(hidden)"
                    }
                } label: {
                    Text("Hide Icon Labels")
                }
            } header: {
                Text("SpringBoard")
            }

            Section {
                Stepper(value: $hsColumns, in: 1...10) {
                    HStack {
                        Text("Home screen columns")
                        Spacer()
                        Text("\(hsColumns)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                
                Stepper(value: $hsRows, in: 1...10) {
                    HStack {
                        Text("Home screen rows")
                        Spacer()
                        Text("\(hsRows)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                Button {
                    run("Patch Home Screen Grid \(hsColumns)x\(hsRows)") {
                        return patch_homescreen_grid(mgr.sbProc, Int32(hsColumns), Int32(hsRows))
                            ? "patch_homescreen_grid(\(hsColumns), \(hsRows)) -> ok"
                            : "patch_homescreen_grid(\(hsColumns), \(hsRows)) -> failed"
                    }
                } label: {
                    Text("Apply Home Screen Grid")
                }
            }

            Section {
                Stepper(value: $columns, in: 1...dockMaxColumns) {
                    HStack {
                        Text("Dock columns")
                        Spacer()
                        Text("\(columns)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .onChange(of: rcdockunlimited) { _ in
                    if !rcdockunlimited, columns > 10 {
                        columns = 10
                    }
                }

                Button {
                    run("Apply Dock Columns=\(columns)") {
                        let result = set_dock_icon_count(mgr.sbProc, Int32(columns))
                        return "set_dock_icon_count(\(columns)) -> \(result)"
                    }
                } label: {
                    Text("Apply Dock Columns")
                }
            }

            Section {
                Button {
                    run("V6: Enable Safe Status Bar Auto-Follow") {
                        return StatusBarAutoFollower.shared.start(mgr: mgr)
                    }
                } label: {
                    Text("V6: Safe Auto-Follow — One Tap")
                }

                Button {
                    let msg = StatusBarAutoFollower.shared.stop()
                    mgr.logmsg("(rc) \(msg)")
                } label: {
                    Text("V6: Stop Auto-Follow")
                }

                Button {
                    let stopMsg = StatusBarAutoFollower.shared.stop()
                    mgr.logmsg("(rc) \(stopMsg)")
                    run("V3: Static Upside-Down Fallback") {
                        let result = apply_v3_upside_down_status_bar(mgr.sbProc)
                        return "apply_v3_upside_down_status_bar() -> \(result)"
                    }
                } label: {
                    Text("Fallback: Working V3 — Static")
                }

                Button {
                    run("V3/V6: Sync Status Bar to Current Orientation") {
                        let result = sync_v6_status_bar_to_active_orientation(mgr.sbProc, 1)
                        return "sync_v6_status_bar_to_active_orientation(force=1) -> \(result)"
                    }
                } label: {
                    Text("Fallback: Sync Current Orientation")
                }

                Button {
                    let stopMsg = StatusBarAutoFollower.shared.stop()
                    mgr.logmsg("(rc) \(stopMsg)")
                    run("V3/V6: Restore Normal Status Bar") {
                        let result = restore_status_bar(mgr.sbProc)
                        return "restore_status_bar() -> \(result)"
                    }
                } label: {
                    Text("Fallback: Restore Layer Transform")
                }

                Button {
                    run("V3 Read-Only Status Bar Geometry") {
                        let result = debug_status_bar_geometry(mgr.sbProc)
                        return "debug_status_bar_geometry() -> \(result)"
                    }
                } label: {
                    Text("Read-Only Geometry Probe")
                }
            } footer: {
                Text("V6 LOCKED: the exact V3 status-bar transform that worked on-device is unchanged. V6.1 only hardens the trigger path: a cached orientation read every 400 ms, and the transform is touched only after an actual portrait flip. The silent-audio keepalive and live SpringBoard RemoteCall are still required while auto-follow is enabled.")
            }

            Section {
                Stepper(value: $dockLiftPoints, in: 12...30, step: 1) {
                    HStack {
                        Text("Upside-down dock lift")
                        Spacer()
                        Text("\(Int(dockLiftPoints)) pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                Button {
                    dockLiftEnabled = true
                    let msg = StatusBarAutoFollower.shared.configureDockLift(enabled: true,
                                                                              points: dockLiftPoints,
                                                                              mgr: mgr)
                    mgr.logmsg("(rc) \(msg)")
                } label: {
                    Text("Enable Upside-Down Dock Lift")
                }

                Button {
                    dockLiftEnabled = false
                    let msg = StatusBarAutoFollower.shared.configureDockLift(enabled: false,
                                                                              points: dockLiftPoints,
                                                                              mgr: mgr)
                    mgr.logmsg("(rc) \(msg)")
                } label: {
                    Text("Restore Stock Dock Position")
                }

                Stepper(value: $bottomGradientHeight, in: 60...160, step: 10) {
                    HStack {
                        Text("Bottom gradient height")
                        Spacer()
                        Text("\(Int(bottomGradientHeight)) pt")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                Button {
                    bottomGradientEnabled = true
                    let msg = StatusBarAutoFollower.shared.configureBottomGradient(enabled: true,
                                                                                    height: bottomGradientHeight,
                                                                                    mgr: mgr)
                    mgr.logmsg("(rc) \(msg)")
                } label: {
                    Text("Enable Upside-Down Black Gradient")
                }

                Button {
                    bottomGradientEnabled = false
                    let msg = StatusBarAutoFollower.shared.configureBottomGradient(enabled: false,
                                                                                    height: bottomGradientHeight,
                                                                                    mgr: mgr)
                    mgr.logmsg("(rc) \(msg)")
                } label: {
                    Text("Disable Bottom Gradient")
                }
            } header: {
                Text("Upside-Down Home Screen")
            } footer: {
                Text("22 pt is the default dock lift (roughly 3–4 mm on an iPhone 12 depending on the effective logical scale). Dock/gradient updates piggy-back on V6 orientation changes and do not add another polling loop. The gradient is intentionally a simple full-width clear→black fade for this first safe pass.")
            }

            Section {
                Button {
                    run("V6.1: Block Shortcuts Notifications") {
                        let r = set_v61_shortcuts_notifications_blocked(mgr.sbProc, 1)
                        return "set_v61_shortcuts_notifications_blocked(1) -> \(r)"
                    }
                } label: {
                    Text("Block Shortcuts Notifications")
                }

                Button {
                    run("V6.1: Restore Shortcuts Notifications") {
                        let r = set_v61_shortcuts_notifications_blocked(mgr.sbProc, 0)
                        return "set_v61_shortcuts_notifications_blocked(0) -> \(r)"
                    }
                } label: {
                    Text("Restore Shortcuts Notifications")
                }
            } header: {
                Text("Shortcuts Notifications")
            } footer: {
                Text("This edits only the saved BulletinBoard section settings for com.apple.shortcuts and persists them through BBServer. It does not install a global notification hook. If Block returns 0, respring once so BBServer reloads the saved section state, then test a normal automation and the post-reboot Shortcuts bulletin.")
            }

            Section {
                Button {
                    run("V5: Enable Floating Dock (Safe Main Thread)") {
                        let result = enable_floating_dock(mgr.sbProc)
                        return "enable_floating_dock() -> \(result)"
                    }
                } label: {
                    Text("V5: Enable Floating Dock (Safe)")
                }
                
                Button {
                    run("Enable Grid App Switcher") {
                        let result = enable_grid_app_switcher(mgr.sbProc)
                        return "enable_grid_app_switcher() -> \(result)"
                    }
                } label: {
                    Text("Enable Grid App Switcher (Broken animation)")
                }
                
                Button {
                    run("Enable UIKit Debug Overlay") {
                        let result = enable_debug_overlay(mgr.sbProc)
                        return "enable_debug_overlay() -> \(result)"
                    }
                } label: {
                    Text("Enable UIKit Debug Overlay")
                }

                /*
                Button {
                    togglefreakydog()
                } label: {
                    Text(freakyrunning ? "Stop Freaky Dog Overlay" : "Start Freaky Dog Overlay")
                }
                */
            } footer: {
                Text("To use UIKit Debug Overlay, double tap the status bar.")
            }
            
            Section {
                Picker("Performance HUD", selection: $performanceHUD) {
                    Text("Off").tag(-1)
                    Text("Basic").tag(0)
                    Text("Backdrops").tag(1)
                    Text("Particles").tag(2)
                    Text("Full").tag(3)
                    Text("Power").tag(5)
                    Text("EDR").tag(7)
                    Text("Glitches").tag(8)
                    Text("GPU Time").tag(9)
                    Text("Memory Bandwidth").tag(10)
                }
                .onChange(of: performanceHUD) { newValue in
                    set_performance_hud(mgr.sbProc, Int32(newValue))
                }
                .onAppear {
                    if mgr.rcrunning {
                        performanceHUD = Int(get_performance_hud(mgr.sbProc))
                    }
                }
            } footer: {
                Text("These call into SpringBoard via RemoteCall. Keep RemoteCall initialized while running them.")
                
                if !mgr.rcready {
                    Text("RemoteCall is not initialized. How are you here?")
                }
            }
            .disabled(!mgr.rcready || running)
            
            if #available(iOS 17.4, *) {
                Section {
                    Button {
                        mgr.rcinitDaemon(serviceName: "com.apple.xpc.amsaccountsd", process: "amsaccountsd", migbypass: false) { proc in
                            guard let proc else {
                                mgr.logmsg("rc init failed")
                                return
                            }
                            mgr.logmsg("rc init succeeded!")
                            mgr.eligibilitystate = euenabler_overwrite_eligibility(proc) == 0
                            mgr.logmsg("overwrite_eligibility() returned: \(mgr.eligibilitystate! ? "success" : "failure")")
                            proc.destroy()
                        }
                    } label: {
                        HStack {
                            Text("Overwrite eligibility (one time setup)")
                            if let state = mgr.eligibilitystate {
                                Spacer()
                                if state {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .disabled(mgr.eligibilitystate ?? false)
                    
                    Button {
                        mgr.eu1progress = 0.0
                        mgr.eu2progress = 0.0
                        mgr.eu1running = true
                        mgr.eu2running = true
                        mgr.rcinitDaemon(serviceName: "com.apple.managedappdistributiond.xpc", process: "managedappdistributiond", migbypass: false) { proc in
                            guard let proc else {
                                mgr.logmsg("rc init failed")
                                mgr.eu1running = false
                                return
                            }
                            mgr.logmsg("rc init succeeded!")
                            euenabler_override_country_code(proc) { progress in
                                DispatchQueue.main.async {
                                    self.mgr.eu1progress = progress
                                }
                            }
                            proc.destroy()
                            DispatchQueue.main.async {
                                mgr.eu1running = false
                            }
                        }
                        // fix unable to load app info
                        mgr.rcinitDaemon(serviceName: "com.apple.appstorecomponentsd.xpc", process: "appstorecomponentsd", migbypass: false) { proc in
                            guard let proc else {
                                mgr.logmsg("rc init failed")
                                mgr.eu2running = false
                                return
                            }
                            mgr.logmsg("rc init succeeded!")
                            euenabler_override_country_code(proc) { progress in
                                DispatchQueue.main.async {
                                    self.mgr.eu2progress = progress
                                }
                            }
                            proc.destroy()
                            DispatchQueue.main.async {
                                mgr.eu2running = false
                            }
                        }
                    } label: {
                        HStack {
                            if mgr.eu1running || mgr.eu2running {
                                ProgressView(value: (mgr.eu1progress + mgr.eu2progress)/2)
                                    .progressViewStyle(.circular)
                                    .frame(width: 18, height: 18)
                                Text("Running...")
                                Spacer()
                                Text("\(Int((mgr.eu1progress + mgr.eu2progress)/2 * 100))%")
                            } else {
                                Text("Enable Spoof EU Region")
                                Spacer()
                                if mgr.eu1progress + mgr.eu2progress == 2 {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.green)
                                } else if mgr.dsattempted && mgr.dsfailed {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .disabled(mgr.eu1running || mgr.eu2running || mgr.eu1progress+mgr.eu2progress == 2)
                } footer: {
                    Text("Enables installing of EU/Japan Marketplace apps.")
                }
                .disabled(isdebugged() || mgr.rcrunning || !mgr.rcready)
            }
            
            Section {
                Button {
                    youtube_tweak(mgr.ytProc)
                } label: {
                    Text("Generic Youtube Tweaks")
                }
            }
            
            Section {
                Button {
                    _ = mgr.rccall(name: "exit", args: [0], timeout: 100)
                } label: {
                    Text("Respring")
                }
            } header: {
                Text("Tools")
            }
            
            Section {
                TextField("Process name", text: $customProcessName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    TextField("Function (symbol or 0xaddr)", text: $customFunctionName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(1)
                    
                    TextEditor(text: $customArgsText)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Stepper(value: $customTimeoutMs, in: 10...5000, step: 10) {
                    HStack {
                        Text("Timeout")
                        Spacer()
                        Text("\(customTimeoutMs) ms")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                Toggle("MIG filter bypass", isOn: $customMigBypass)

                Button {
                    run("Custom RemoteCall \(customProcessName):\(customFunctionName)") {
                        let process = customProcessName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let function = customFunctionName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !process.isEmpty else { return "custom: missing process name" }
                        guard !function.isEmpty else { return "custom: missing function name" }

                        let (args, parseError) = parseRemoteCallArgs(customArgsText)
                        if let parseError {
                            return "custom: args parse error: \(parseError)"
                        }

                        let ptr: UnsafeMutableRawPointer?
                        if let addr = parseAddress(function) {
                            ptr = UnsafeMutableRawPointer(bitPattern: UInt(addr))
                        } else {
                            let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
                            ptr = function.withCString { dlsym(RTLD_DEFAULT, $0) }
                        }

                        guard let ptr else {
                            return "custom: failed to resolve \(function)"
                        }

                        guard let proc = RemoteCall(process: process, useMigFilterBypass: customMigBypass) else {
                            return "custom: RemoteCall init failed for \(process)"
                        }
                        defer { proc.destroy() }

                        var argsCopy = args
                        let ret = function.withCString { (cName: UnsafePointer<CChar>) -> UInt64 in
                            UInt64(argsCopy.withUnsafeMutableBufferPointer { buffer in
                                proc.doStable(
                                    withTimeout: Int32(customTimeoutMs),
                                    functionName: UnsafeMutablePointer(mutating: cName),
                                    functionPointer: ptr,
                                    args: buffer.baseAddress,
                                    argCount: UInt(args.count)
                                )
                            })
                        }

                        let err = proc.lastError ?? ""
                        let suffix = err.isEmpty ? "" : " (err: \(err))"
                        return "custom: \(process) \(function)(\(args.count) args) -> 0x\(String(ret, radix: 16)) / \(ret)\(suffix)"
                    } onComplete: { msg in
                        self.customLastResult = msg
                    }
                } label: {
                    Text("Call")
                }

                if !customLastResult.isEmpty {
                    Text(customLastResult)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Custom RemoteCall")
            } footer: {
                Text("Calls a symbol (via dlsym) or an absolute address. Numeric args are passed as x0-x7 then stack.")
            }
            .disabled(!mgr.rcready || running)

            Section {
                HStack(alignment: .top) {
                    AsyncImage(url: URL(string: "https://github.com/khanhduytran0.png")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Duy Tran")
                            .font(.headline)
                        
                        Text("Responsible for most things related to remotecall.")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    
                    Spacer()
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/khanhduytran0"),
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
                
                HStack(alignment: .top) {
                    AsyncImage(url: URL(string: "https://github.com/zeroxjf.png")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("0xjf")
                            .font(.headline)
                        
                        Text("Powercuff and SBCustomizer")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    
                    Spacer()
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/zeroxjf"),
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
                
                HStack(alignment: .top) {
                    AsyncImage(url: URL(string: "https://github.com/Scr-eam.png")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Scream")
                            .font(.headline)
                        
                        Text("Fixed Hide Icon Labels")
                            .font(.subheadline)
                            .foregroundColor(Color.secondary)
                    }
                    
                    Spacer()
                }
                .onTapGesture {
                    if let url = URL(string: "https://github.com/Scr-eam"),
                       UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text("Credits")
            }
        }
        .navigationTitle(Text("Tweaks"))
        .onDisappear {
            if freakyrunning, let proc = mgr.sbProc {
                stopfreakydog(proc)
            }
        }
    }

    private func run(_ name: String, _ work: @escaping () -> String, onComplete: ((String) -> Void)? = nil) {
        guard mgr.rcready, !running else { return }
        running = true
        StatusBarAutoFollower.shared.setExternalActionRunning(true)
        mgr.logmsg("(rc) \(name)...")

        DispatchQueue.global(qos: .userInitiated).async {
            let result = work()
            DispatchQueue.main.async {
                self.mgr.logmsg("(rc) \(result)")
                onComplete?(result)
                self.running = false
                StatusBarAutoFollower.shared.setExternalActionRunning(false)
            }
        }
    }

    private func togglefreakydog() {
        guard mgr.rcready, let proc = mgr.sbProc else { return }

        if freakyrunning {
            stopfreakydog(proc)
            return
        }

        let view = enable_freaky_dog_overlay(proc)
        guard view != 0 else {
            mgr.logmsg("(rc) enable_freaky_dog_overlay() failed")
            return
        }

        let seq = freakyseq + 1
        freakyseq = seq
        freakyrunning = true
        mgr.logmsg("(rc) enable_freaky_dog_overlay() -> 0x\(String(view, radix: 16))")

        let screen = UIScreen.main.bounds
        let maxw = max(Int(screen.width), 200)
        let maxh = max(Int(screen.height), 300)

        DispatchQueue.global(qos: .userInitiated).async {
            while true {
                let shouldcontinue = DispatchQueue.main.sync { () -> Bool in
                    self.freakyrunning && self.freakyseq == seq && self.mgr.rcready && self.mgr.sbProc != nil
                }
                if !shouldcontinue {
                    break
                }

                let size = Int.random(in: 110...220)
                let x = Int.random(in: 0...max(maxw - size, 0))
                let y = Int.random(in: 40...max(maxh - size, 40))
                let result = move_freaky_dog_overlay(proc, view, Int32(x), Int32(y), Int32(size), Int32(size))
                if result != 0 {
                    DispatchQueue.main.async {
                        self.mgr.logmsg("(rc) move_freaky_dog_overlay() failed: \(result)")
                        self.stopfreakydog(proc)
                    }
                    break
                }

                usleep(UInt32.random(in: 25000...90000))
            }
        }
    }

    private func stopfreakydog(_ proc: RemoteCall) {
        freakyrunning = false
        freakyseq += 1
        let result = disable_freaky_dog_overlay(proc)
        mgr.logmsg("(rc) disable_freaky_dog_overlay() -> \(result)")
    }

    private func parseRemoteCallArgs(_ text: String) -> (args: [UInt64], error: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ([], nil) }

        let separators = CharacterSet(charactersIn: ", \t\r\n")
        let tokens = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var out: [UInt64] = []
        out.reserveCapacity(tokens.count)

        for token in tokens {
            if let value = parseUInt64OrInt64BitPattern(token) {
                out.append(value)
            } else {
                return ([], "bad token '\(token)'")
            }
        }

        return (out, nil)
    }

    private func parseUInt64OrInt64BitPattern(_ token: String) -> UInt64? {
        if token.hasPrefix("-") {
            let rest = String(token.dropFirst())
            if rest.lowercased().hasPrefix("0x") {
                let hex = String(rest.dropFirst(2))
                guard let magnitude = UInt64(hex, radix: 16) else { return nil }
                let signed = -Int64(bitPattern: magnitude)
                return UInt64(bitPattern: signed)
            } else {
                guard let signed = Int64(rest) else { return nil }
                return UInt64(bitPattern: -signed)
            }
        }

        if token.lowercased().hasPrefix("0x") {
            return UInt64(token.dropFirst(2), radix: 16)
        }

        return UInt64(token)
    }

    private func parseAddress(_ functionField: String) -> UInt64? {
        let s = functionField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.lowercased().hasPrefix("0x") else { return nil }
        guard let value = UInt64(s.dropFirst(2), radix: 16) else { return nil }
        guard value <= UInt64(UInt.max) else { return nil }
        return value
    }
}
