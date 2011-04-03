//
//  PlaylistOutlineView.m
//  Lyricus
//
//  Created by Thomas Backman on 4/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PlaylistOutlineView.h"


@implementation PlaylistOutlineView

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)mouseDown:(NSEvent *)theEvent {
	// Check if the clicked row is the selected row; if so,
	// send a notification, since one is otherwise only sent
	// when a NEW row is clicked.
	
	// This should really be done in mouseUp, but no such event
	// appears to be sent when clicking a row.
	
	NSRect rowRect = [self rectOfRow:[self selectedRow]];
	NSPoint locationinView = [self convertPoint:[theEvent locationInWindow] fromView:[[self window] contentView]];
	
	if (NSPointInRect(locationinView, rowRect)) {
		id /*<NSOutlineViewDelegate>*/ del = [self delegate];
		if ([del respondsToSelector:@selector(outlineViewSelectionDidChange:)]) {
			[del outlineViewSelectionDidChange:[NSNotification notificationWithName:@"NSOutlineViewSelectionDidChangeNotification" object:self userInfo:nil]];
		}
	}

	[super mouseDown:theEvent];
}

- (void)dealloc
{
    [super dealloc];
}

@end
