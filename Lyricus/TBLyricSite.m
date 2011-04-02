//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "TBLyricSite.h"


@implementation TBLyricSite

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
