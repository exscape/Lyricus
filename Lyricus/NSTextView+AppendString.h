
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextView (AppendString)

-(void)removeStringOfLength:(NSInteger)length;
-(void)appendString:(NSString *)theString;
-(void)appendImageNamed:(NSString *)imageName;

@end

