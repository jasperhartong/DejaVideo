<h1 align="center">DejaVideo</h1>

<div align="center">
  <img src="https://user-images.githubusercontent.com/47074382/86511221-41660c00-bdf7-11ea-8af9-3a6b5ffe66a7.png" alt="DejaVideo Logo" />
</div>
<div align="center">
  <strong>Jump back into the past, anytime.</strong>
</div>
<div align="center">
  A small, continuous screen recording utility for Mac
</div>

<div align="center">
  <sub>Built with ❤︎ by
    <a href="https://twitter.com/jasperhartong">Jasper Hartong</a>
  </sub>
  <br/>
  <br/>
  <img src="https://img.shields.io/endpoint?style=flat-square&url=https%3A%2F%2Femittime.app%2Fapi%2Fshieldio%2FQgAxKVLdk" alt="Emit/Time Shield" />
</div>
  
## About

![menu_bar_2 011d1b4b](https://user-images.githubusercontent.com/47074382/86511143-71f97600-bdf6-11ea-825a-41610a44d8a8.png)


DejaVideo lives in your menu bar. It allows you to record your screen continuously and to export the last minute at any moment.

* With a minimum impact on your Mac, you can let it record always.
* Supports both dark and light mode
* 100% offline (No phoning home, no analytics, no update mechanisms)
* Opens the screen recording in QuickTime upong exporting. Hit <code>⌘ T</code> and trim it to your needs.
* Has a fancy loading animation to indicate which screen is being recorded

<a href="https://www.producthunt.com/posts/dejavideo?utm_source=badge-featured&utm_medium=badge&utm_souce=badge-dejavideo" target="_blank"><img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=141896&theme=light" alt="DejaVideo - Continuous screen recorder for Mac, jump back anytime. | Product Hunt Embed" style="width: 250px; height: 54px;" width="250px" height="54px" /></a>

## Releases

* [v1.0.2](https://github.com/jasperhartong/DejaVideo/releases/tag/v1.0.2) – The initial release of DejaVideo plus some additional minor fixes.
* v1.1.0 – **[Unreleased]** Adds additional settings for scaling, fps and interval to record. See [PR #1](https://github.com/jasperhartong/DejaVideo/pull/1)

## ⚠️ Disclaimer

This code was my first stab at using Swift. It's source is now public, because.. why not?

## 🔨 Development Tips

### Summary of the main logic

The [ContinuousRecording](https://github.com/jasperhartong/DejaVideo/blob/readme-update/ContinuousRecorder/Models/ContinuousRecorder.swift#L152) state-machine aggregates a list of [ScaledRecordingFragments](https://github.com/jasperhartong/DejaVideo/blob/readme-update/ContinuousRecorder/Models/ContinuousRecorder.swift#L67) (storing the current screen image and mousePoint position), based on the firing of a [RepeatingBackgroundTimer](https://github.com/jasperhartong/DejaVideo/blob/readme-update/ContinuousRecorder/Utils/RepeatingBackgroundTimer.swift). When exporting to video, the [VidWriter](https://github.com/jasperhartong/DejaVideo/blob/readme-update/ContinuousRecorder/Utils/VidWriter.swift) merges these fragments using CVPixelBuffer.

### Running the project

Open up the .xcodeproj, run and DejaVideo should appear in your menu bar.

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

