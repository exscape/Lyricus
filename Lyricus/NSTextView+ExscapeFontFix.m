//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

@implementation NSTextView (ExscapeFontFix)

- (void)changeFont:(id)sender {
    NSFont *oldFont = [self font];
    NSFont *newFont = [sender convertFont:oldFont];
	[self setFont:newFont];
	
	[[NSUserDefaults standardUserDefaults] setObject:[newFont fontName] forKey:@"FontName"];
	[[NSUserDefaults standardUserDefaults] setFloat:[newFont pointSize] forKey:@"FontSize"];

	// ... this causes an exception in [NSText changeFont:]. Why?!
	//	[super changeFont:sender];
}

@end
