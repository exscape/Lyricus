//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "NSTextView+AppendString.h"

@implementation NSTextView (AppendString)

-(void)appendString:(NSString *)theString {
	if (theString == nil || [theString length] < 1)
		return;
	
	NSMutableAttributedString *attributedString = [[[NSAttributedString alloc] initWithString:theString] mutableCopy];
	
	NSColor *foreColor = [self textColor];
	NSColor *backColor = [self backgroundColor];
	if (foreColor == nil)
		foreColor = [NSColor blackColor];
	if (backColor == nil)
		backColor = [NSColor whiteColor];
	
	[attributedString addAttribute:NSBackgroundColorAttributeName value:backColor range:NSMakeRange(0, [attributedString length])];
	[attributedString addAttribute:NSForegroundColorAttributeName value:foreColor range:NSMakeRange(0, [attributedString length])];
	
	[[self textStorage] replaceCharactersInRange:NSMakeRange([[self textStorage] length], 0) withAttributedString:attributedString];

	[self scrollRangeToVisible:NSMakeRange([[self textStorage] length], 0)];
}

-(void)appendImageNamed:(NSString *)imageName {
	NSImage *image = [NSImage imageNamed:imageName];
	NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:image];
	NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
	[attachment setAttachmentCell:attachmentCell];
	NSMutableAttributedString *attributedString = [[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy];
	
	NSColor *foreColor = [self textColor];
	NSColor *backColor = [self backgroundColor];
	if (foreColor == nil)
		foreColor = [NSColor blackColor];
	if (backColor == nil)
		backColor = [NSColor whiteColor];

	[attributedString addAttribute:NSBackgroundColorAttributeName value:backColor range:NSMakeRange(0, [attributedString length])];
	[attributedString addAttribute:NSForegroundColorAttributeName value:foreColor range:NSMakeRange(0, [attributedString length])];
	
	[[self textStorage] appendAttributedString:attributedString];
}

@end