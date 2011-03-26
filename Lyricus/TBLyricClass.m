//
//  TBLyricClass.m
//  Lyricus
//
//  Created by Thomas Backman on 3/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TBLyricClass.h"


@implementation TBLyricClass

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)sendStatusUpdate:(NSString *)text ofType:(int)type {
	[[NSNotificationCenter defaultCenter] postNotificationName:@"UpdateStatusNotification" object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:type], @"type",text, @"Text", nil]];
}


- (void)dealloc
{
    [super dealloc];
}

@end
