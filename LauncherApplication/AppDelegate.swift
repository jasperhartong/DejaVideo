import Cocoa

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject {
    
    @objc func terminate() {
        NSApp.terminate(nil)
    }
}

let mainAppName = "ContinuousRecorder"
let mainAppIdentifier = "deblonde.\(mainAppName)"

extension AppDelegate: NSApplicationDelegate {

    // LauncherApplication kickstarts the main application
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("LauncherApplication: \(#function)")
        if !isMainAppRunning {
            NSLog("LauncherApplication:: main app is not running yet: boot it and wait")
            observeKillSignalFromMainApp()
            NSWorkspace.shared.launchApplication(getMainAppPath())
        }
        else {
            self.terminate()
        }
    }
    
    private var isMainAppRunning: Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty
    }
    
    private func getMainAppPath() -> String {
        let path = Bundle.main.bundlePath as NSString
        var components = path.pathComponents
        components.removeLast()
        components.removeLast()
        components.removeLast()
        components.append("MacOS")
        components.append(mainAppName)
        
        return NSString.path(withComponents: components)
    }
    
    private func observeKillSignalFromMainApp() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(self.terminate),
            name: .killLauncher,
            object: mainAppIdentifier)
    }
}
