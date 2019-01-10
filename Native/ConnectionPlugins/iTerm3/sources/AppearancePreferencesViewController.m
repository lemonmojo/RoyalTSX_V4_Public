//
//  AppearancePreferencesViewController.m
//  iTerm
//
//  Created by George Nachman on 4/6/14.
//
//

#import "AppearancePreferencesViewController.h"
#import "iTermHotKeyController.h"
#import "iTermApplicationDelegate.h"
#import "iTermWarning.h"
#import "PreferencePanel.h"

NSString *const iTermProcessTypeDidChangeNotification = @"iTermProcessTypeDidChangeNotification";

@implementation AppearancePreferencesViewController {
    // This is actually the tab style. See TAB_STYLE_XXX defines.
    IBOutlet NSPopUpButton *_tabStyle;

    // Tab position within window. See TAB_POSITION_XXX defines.
    IBOutlet NSPopUpButton *_tabPosition;

    // Hide tab bar when there is only one session
    IBOutlet NSButton *_hideTab;

    // Remove tab number from tabs.
    IBOutlet NSButton *_hideTabNumber;

    // Remove close button from tabs.
    IBOutlet NSButton *_hideTabCloseButton;

    // Hide activity indicator.
    IBOutlet NSButton *_hideActivityIndicator;

    // Show new-output indicator
    IBOutlet NSButton *_showNewOutputIndicator;

    // Show per-pane title bar with split panes.
    IBOutlet NSButton *_showPaneTitles;

    // Hide menu bar in non-lion fullscreen.
    IBOutlet NSButton *_hideMenuBarInFullscreen;

    // Exclude from dock and cmd-tab (LSUIElement)
    IBOutlet NSButton *_uiElement;

    IBOutlet NSButton *_flashTabBarInFullscreenWhenSwitchingTabs;
    IBOutlet NSButton *_showTabBarInFullscreen;

    IBOutlet NSButton *_stretchTabsToFillBar;

    // Show window number in title bar.
    IBOutlet NSButton *_windowNumber;

    // Show job name in title
    IBOutlet NSButton *_jobName;

    // Show bookmark name in title.
    IBOutlet NSButton *_showBookmarkName;

    // Dim text (and non-default background colors).
    IBOutlet NSButton *_dimOnlyText;

    // Dimming amount.
    IBOutlet NSSlider *_dimmingAmount;

    // Dim inactive split panes.
    IBOutlet NSButton *_dimInactiveSplitPanes;

    // Dim background windows.
    IBOutlet NSButton *_dimBackgroundWindows;

    // Window border.
    IBOutlet NSButton *_showWindowBorder;

    // Hide scrollbar.
    IBOutlet NSButton *_hideScrollbar;

    // Disable transparency in fullscreen by default.
    IBOutlet NSButton *_disableFullscreenTransparency;

    // Draw line under title bar when the tab bar is not visible
    IBOutlet NSButton *_enableDivisionView;

    IBOutlet NSButton *_enableProxyIcon;
}

- (void)awakeFromNib {
    PreferenceInfo *info;

    __weak __typeof(self) weakSelf = self;
    info = [self defineControl:_tabPosition
                           key:kPreferenceKeyTabPosition
                          type:kPreferenceInfoTypePopup];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    if (@available(macOS 10.14, *)) { } else {
        // Remove "automatic" and separator prior to 10.14
        [_tabStyle.menu removeItem:_tabStyle.menu.itemArray.firstObject];
        [_tabStyle.menu removeItem:_tabStyle.menu.itemArray.firstObject];
    }
    info = [self defineControl:_tabStyle
                           key:kPreferenceKeyTabStyle
                          type:kPreferenceInfoTypePopup];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };


    info = [self defineControl:_hideTab
                           key:kPreferenceKeyHideTabBar
                          type:kPreferenceInfoTypeInvertedCheckbox];
    info.onChange = ^() {
        [weakSelf postRefreshNotification];
        [weakSelf updateFlashTabsVisibility];
    };

    info = [self defineControl:_hideTabNumber
                           key:kPreferenceKeyHideTabNumber
                          type:kPreferenceInfoTypeInvertedCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_hideTabCloseButton
                           key:kPreferenceKeyHideTabCloseButton
                          type:kPreferenceInfoTypeInvertedCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_hideActivityIndicator
                           key:kPreferenceKeyHideTabActivityIndicator
                          type:kPreferenceInfoTypeInvertedCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_showNewOutputIndicator
                           key:kPreferenceKeyShowNewOutputIndicator
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_showPaneTitles
                           key:kPreferenceKeyShowPaneTitles
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_hideMenuBarInFullscreen
                           key:kPreferenceKeyHideMenuBarInFullscreen
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };
    
    info = [self defineControl:_uiElement
                           key:kPreferenceKeyUIElement
                          type:kPreferenceInfoTypeCheckbox];
    info.customSettingChangedHandler = ^(id sender) {
        BOOL isOn = [sender state] == NSOnState;
        BOOL didChange = NO;
        if (isOn) {
            iTermWarningSelection selection =
                [iTermWarning showWarningWithTitle:@"When iTerm2 is excluded from the dock, you can "
                                                   @"always get back to Preferences using the status "
                                                   @"bar item. Look for an iTerm2 icon on the right "
                                                   @"side of your menu bar."
                                           actions:@[ @"Exclude From Dock and App Switcher", @"Cancel" ]
                                        identifier:nil
                                       silenceable:kiTermWarningTypePersistent
                                            window:weakSelf.view.window];
            if (selection == kiTermWarningSelection0) {
                [weakSelf setBool:YES forKey:kPreferenceKeyUIElement];
                [weakSelf setBool:NO forKey:kPreferenceKeyHideMenuBarInFullscreen];
                didChange = YES;
            }
        } else {
            didChange = YES;
            [weakSelf setBool:NO forKey:kPreferenceKeyUIElement];
        }
        if (didChange) {
            __strong __typeof(self) strongSelf = weakSelf;
            if (strongSelf) {
                if (isOn) {
                    strongSelf->_hideMenuBarInFullscreen.state = NSOffState;
                }
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:iTermProcessTypeDidChangeNotification
                                                            object:nil];
    };

    [self defineControl:_flashTabBarInFullscreenWhenSwitchingTabs
                    key:kPreferenceKeyFlashTabBarInFullscreen
                   type:kPreferenceInfoTypeCheckbox];
    [self updateFlashTabsVisibility];

    info = [self defineControl:_showTabBarInFullscreen
                           key:kPreferenceKeyShowFullscreenTabBar
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() {
        [[NSNotificationCenter defaultCenter] postNotificationName:kShowFullscreenTabsSettingDidChange
                                                            object:nil];
    };

    // There's a menu item to change this setting. We want the control to reflect it.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showFullscreenTabsSettingDidChange:)
                                                 name:kShowFullscreenTabsSettingDidChange
                                               object:nil];

    info = [self defineControl:_stretchTabsToFillBar
                           key:kPreferenceKeyStretchTabsToFillBar
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_windowNumber
                           key:kPreferenceKeyShowWindowNumber
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postUpdateLabelsNotification]; };

    info = [self defineControl:_jobName
                           key:kPreferenceKeyShowJobName
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postUpdateLabelsNotification]; };

    info = [self defineControl:_showBookmarkName
                           key:kPreferenceKeyShowProfileName
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postUpdateLabelsNotification]; };

    info = [self defineControl:_dimOnlyText
                           key:kPreferenceKeyDimOnlyText
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_dimmingAmount
                           key:kPreferenceKeyDimmingAmount
                          type:kPreferenceInfoTypeSlider];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_dimInactiveSplitPanes
                           key:kPreferenceKeyDimInactiveSplitPanes
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_dimBackgroundWindows
                           key:kPreferenceKeyDimBackgroundWindows
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_showWindowBorder
                           key:kPreferenceKeyShowWindowBorder
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_hideScrollbar
                           key:kPreferenceKeyHideScrollbar
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_disableFullscreenTransparency
                           key:kPreferenceKeyDisableFullscreenTransparencyByDefault
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_enableDivisionView
                           key:kPreferenceKeyEnableDivisionView
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };

    info = [self defineControl:_enableProxyIcon
                           key:kPreferenceKeyEnableProxyIcon
                          type:kPreferenceInfoTypeCheckbox];
    info.onChange = ^() { [weakSelf postRefreshNotification]; };
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)postUpdateLabelsNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:kUpdateLabelsNotification
                                                        object:nil
                                                      userInfo:nil];
}

- (void)showFullscreenTabsSettingDidChange:(NSNotification *)notification {
    _showTabBarInFullscreen.state =
        [iTermPreferences boolForKey:kPreferenceKeyShowFullscreenTabBar] ? NSOnState : NSOffState;
    [self updateFlashTabsVisibility];
}

- (void)updateFlashTabsVisibility {
    // Enable flashing tabs in fullscreen when it's possible for the tab bar in fullscreen to be
    // hidden: either it's not always visible or it's hidden when there's a single tab. The single-
    // tab case is relevant when going from two tabs to one, which could be considered a "switch".
    _flashTabBarInFullscreenWhenSwitchingTabs.enabled =
        (![iTermPreferences boolForKey:kPreferenceKeyShowFullscreenTabBar] ||
         [iTermPreferences boolForKey:kPreferenceKeyHideTabBar]);
}

@end
