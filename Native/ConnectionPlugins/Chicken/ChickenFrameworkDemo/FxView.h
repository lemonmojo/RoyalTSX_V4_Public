//
//  FxView.h
//  ChickenTester
//
//  Created by Felix Deimel on 08.10.13.
//  Copyright (c) 2013 Lemon Mojo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FxView : NSView {
    id delegate;
}

@property (nonatomic, assign) id delegate;

@end
