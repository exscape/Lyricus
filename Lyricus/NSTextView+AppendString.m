//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "NSTextView+AppendString.h"

@implementation NSTextView (AppendString)

-(void)appendString:(NSString *)theString {
	if (theString == nil || [theString length] < 1)
		return;
	BOOL oldEditable = [self isEditable];
	[self setEditable:YES];
	NSRange oldSel = [self selectedRange];
	[self setSelectedRange:NSMakeRange([[self textStorage] length], [[self textStorage] length])];
	[self insertText:theString];
	[self setEditable:oldEditable];
	[self setSelectedRange:oldSel];
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