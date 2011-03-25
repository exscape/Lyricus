//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Cocoa/Cocoa.h>

@interface NSTextView (AppendString)

-(void)appendString:(NSString *)theString;
-(void)appendImageNamed:(NSString *)imageName;

@end

