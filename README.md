#  Continuous Recorder

This code was my first stab at using Swift. I never got around to writing a proper README at the time and now future me is kind of mad at past me. It's source is now public, because.. why not?

## Running it

Open up the .xcodeproj, run and DejaVideo should appear in your menu bar.

## Packing the release in a dmg

- Build a release
- Use https://github.com/sindresorhus/create-dmg

## Starting at login

In order to let this work during development, there should be only 1 app found for the bundle identifier of the LauncherApplication.

To check whether MacOs finds ONLY the correct build (which should be /Applications):

```
import Cocoa

let bundleId = "deblonde.LauncherApplication"
let paths = LSCopyApplicationURLsForBundleIdentifier(bundleId as CFString, nil)
print("Available service instances by bundle id: \(String(describing: paths))")
```

To remove builds:
- make sure to clean the project (`⌘ + Shift + alt + K`).
- make sure to clean the archives (`⌘ + Shift + 6`)

Also, it could help to bump the build number in the General options of the project

### Launchctl

In the end `deblonde.LauncherApplication` should be registered in launchctl, you can check or interact with it:

```
$launchctl list
$launchctl remove deblonde.LauncherApplication
```
