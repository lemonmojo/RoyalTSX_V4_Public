//
//  FxView.m
//  ChickenTester
//
//  Created by Felix Deimel on 08.10.13.
//  Copyright (c) 2013 Lemon Mojo. All rights reserved.
//

#import "FxView.h"

@implementation FxView

@synthesize delegate;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)viewDidEndLiveResize
{
    [delegate viewDidEndLiveResize];
}

@end
