<h1 align="center">DejaVideo</h1>

<div align="center">
  <img src="https://user-images.githubusercontent.com/47074382/86510743-9ce1cb00-bdf2-11ea-9295-832d2ba67660.png" alt="DejaVideo Logo" />
</div>

<div align="center">
  <sub>A small screen recording utility. Built with ❤︎ by
  <a href="https://twitter.com/jasperhartong">Jasper Hartong</a>
</div>

## Disclaimer

This code was my first stab at using Swift. I never got around to writing a proper README at the time and now future me is kind of mad at past me. It's source is now public, because.. why not?

## Running it

Open up the .xcodeproj, run and DejaVideo should appear in your menu bar.

## Development Tips

### Packing the release in a dmg

- Build a release
- Use https://github.com/sindresorhus/create-dmg

### Test starting at login

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

#### Launchctl

In the end `deblonde.LauncherApplication` should be registered in launchctl, you can check or interact with it:

```
$launchctl list
$launchctl remove deblonde.LauncherApplication
```
