# Royal TSX V4 Public Source Code

### What's included
Right now, the native code portion of the [iTerm2](https://github.com/gnachman/iTerm2) plugin as well as the native code portion of the [Chicken VNC](https://sourceforge.net/projects/cotvnc/) plugin are included in this repository.

### iTerm2
Changes from the original code by [gnachman](https://github.com/gnachman) are annotated with [`iTermLib Edit`](https://github.com/lemonmojo/RoyalTSX_V4_Public/search?q=iTermLib+Edit&unscoped_q=iTermLib+Edit). The project includes two additional targets:
* **iTerm2Lib**: This builds a Cocoa framework that includes everything necessary to create iTerm2 terminal instances and embed them in `NSView`s.
* **iTerm2LibDemo**: This builds a Cocoa application that showcases the functionality in the iTerm2Lib.framework.

### Chicken VNC
The project includes two additional targets:
* **ChickenVncFramework**: This builds a Cocoa framework that includes everything necessary to create Chicken VNC instances and embed them in `NSView`s.
* **ChickenFrameworkDemo**: This builds a Cocoa application that showcases the functionality in the ChickenVncFramework.framework.

### Support
If you need additional information, please [contact us](https://royalapplications.com/go/support).
