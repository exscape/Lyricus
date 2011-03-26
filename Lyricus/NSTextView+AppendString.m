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
	
	[[self textStorage] replaceCharactersInRange:NSMakeRange([[self textStorage] length], 0) withAttributedString:
	 [[NSAttributedString alloc] initWithString:theString]];
	[self scrollRangeToVisible:NSMakeRange([[self textStorage] length], 0)];
}

-(void)appendImageNamed:(NSString *)imageName {
	NSImage *image = [NSImage imageNamed:imageName];
	NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:image];
	NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
	[attachment setAttachmentCell:attachmentCell];
	NSAttributedString *attributedString = [NSAttributedString attributedStringWithAttachment:attachment];
	[[self textStorage] appendAttributedString:attributedString];
}

@end