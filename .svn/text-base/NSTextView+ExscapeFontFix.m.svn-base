
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

@implementation NSTextView (ExscapeFontFix)

- (void)changeFont:(id)sender
{
    NSFont *oldFont = [self font];
    NSFont *newFont = [sender convertFont:oldFont];
	[self setFont:newFont];
	
	[[NSUserDefaults standardUserDefaults] setObject:[newFont fontName] forKey:@"FontName"];
	[[NSUserDefaults standardUserDefaults] setFloat:[newFont pointSize] forKey:@"FontSize"];
	
	[super changeFont:sender];
}

@end
