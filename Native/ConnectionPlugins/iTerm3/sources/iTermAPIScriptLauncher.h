//
//  iTermAPIScriptLauncher.h
//  iTerm2SharedARC
//
//  Created by George Nachman on 4/19/18.
//

#import <Cocoa/Cocoa.h>

@interface iTermAPIScriptLauncher : NSObject

// Launches an API script. Reads its output and waits for it to terminate.
+ (void)launchScript:(NSString *)filename;
+ (void)launchScript:(NSString *)filename withVirtualEnv:(NSString *)virtualenv;
+ (NSString *)environmentForScript:(NSString *)path checkForMain:(BOOL)checkForMain;
+ (NSString *)pythonVersion;
+ (NSString *)prospectivePythonPathForPyenvScriptNamed:(NSString *)name;

@end
