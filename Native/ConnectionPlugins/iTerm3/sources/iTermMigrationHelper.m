//
//  iTermMigrationHelper.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 6/1/18.
//

#import "iTermMigrationHelper.h"

#import "iTermDisclosableView.h"
#import "NSFileManager+iTerm.h"

@implementation iTermMigrationHelper

+ (BOOL)removeLegacyAppSupportFolderIfPossible {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *legacy = [fileManager legacyApplicationSupportDirectory];

    if (![fileManager itemIsDirectory:legacy]) {
        return NO;
    }

    BOOL foundVersionTxt = NO;
    for (NSString *file in [fileManager enumeratorAtPath:legacy]) {
        if ([file isEqualToString:@"version.txt"]) {
            foundVersionTxt = YES;
        } else {
            return NO;
        }
    }
    if (foundVersionTxt) {
        NSError *error = nil;
        [fileManager removeItemAtPath:[legacy stringByAppendingPathComponent:@"version.txt"] error:&error];
        if (error) {
            return NO;
        }
    }

    NSError *error = nil;
    [fileManager removeItemAtPath:legacy error:&error];
    return error == nil;
}

+ (void)migrateApplicationSupportDirectoryIfNeeded {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *modern = [fileManager applicationSupportDirectory];
    NSString *legacy = [fileManager legacyApplicationSupportDirectory];

    if ([fileManager itemIsSymlink:legacy]) {
        // Looks migrated, or crazy and impossible to reason about.
        return;
    }

    if ([self removeLegacyAppSupportFolderIfPossible]) {
        return;
    }

    if ([fileManager itemIsDirectory:modern] && [fileManager itemIsDirectory:legacy]) {
        // This is the normal code path for migrating users.
        const BOOL legacyEmpty = [fileManager directoryEmpty:legacy];

        if (legacyEmpty) {
            [fileManager removeItemAtPath:legacy error:nil];
            [fileManager createSymbolicLinkAtPath:legacy withDestinationPath:modern error:nil];
            return;
        }

        const BOOL modernEmpty = [fileManager directoryEmpty:modern];
        if (modernEmpty) {
            [fileManager removeItemAtPath:modern error:nil];
            [fileManager moveItemAtPath:legacy toPath:modern error:nil];
            [fileManager createSymbolicLinkAtPath:legacy withDestinationPath:modern error:nil];
            return;
        }

        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Manual Update Needed";
        alert.informativeText = @"iTerm2's Application Support directory has changed.\n\n"
        @"Previously, both these directories were supported:\n~/Library/Application Support/iTerm\n~/Library/Application Support/iTerm2.\n\n"
            @"Now, only the iTerm2 version is supported. But you have files in both so please move everything from iTerm to iTerm2.";

        NSMutableArray<NSString *> *files = [NSMutableArray array];
        int over = 0;
        for (NSString *file in [fileManager enumeratorAtPath:legacy]) {
            if (files.count > 5) {
                over++;
            } else {
                [files addObject:file];
            }
        }
        [files sortUsingSelector:@selector(compare:)];
        NSString *message;
        if (over == 0) {
            message = [files componentsJoinedByString:@"\n"];
        } else {
            message = [NSString stringWithFormat:@"%@\n…and %@ more", [files componentsJoinedByString:@"\n"], @(over)];
        }

        iTermDisclosableView *accessory = [[iTermDisclosableView alloc] initWithFrame:NSZeroRect
                                                                               prompt:@"Directory Listing"
                                                                              message:message];
        accessory.frame = NSMakeRect(0, 0, accessory.intrinsicContentSize.width, accessory.intrinsicContentSize.height);
        accessory.textView.selectable = YES;
        accessory.requestLayout = ^{
            [alert layout];
        };
        alert.accessoryView = accessory;

        [alert addButtonWithTitle:@"Open in Finder"];
        [alert addButtonWithTitle:@"I Fixed It"];
        [alert addButtonWithTitle:@"Not Now"];
        switch ([alert runModal]) {
            case NSAlertFirstButtonReturn:
                [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ [NSURL fileURLWithPath:legacy],
                                                                              [NSURL fileURLWithPath:modern] ]];
                [self migrateApplicationSupportDirectoryIfNeeded];
                break;

            case NSAlertThirdButtonReturn:
                return;

            default:
                [self migrateApplicationSupportDirectoryIfNeeded];
                break;
        }
    }
}

@end

