//
//  LyricTextView.m
//  Lyricus
//
//  Created by Thomas Backman on 4/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "LyricTextView.h"

@implementation LyricTextView

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(NSArray *)acceptableDragTypes {
	return [NSArray arrayWithObject:kLyricusTrackDragType];
}

-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	if ([[[sender draggingPasteboard] types] containsObject:kLyricusTrackDragType]) {
		if ([sender draggingSourceOperationMask] & NSDragOperationCopy) {
			return NSDragOperationCopy;
		}
	}
	
	return NSDragOperationNone;
}

-(NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
	if ([[[sender draggingPasteboard] types] containsObject:kLyricusTrackDragType]) {
		if ([sender draggingSourceOperationMask] & NSDragOperationCopy) {
			return NSDragOperationCopy;
		}
	}
	
	return NSDragOperationNone;
}

-(BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
	return YES;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	NSData *data = [[sender draggingPasteboard] dataForType:kLyricusTrackDragType];
	NSDictionary *track = [NSKeyedUnarchiver unarchiveObjectWithData:data];

	if ([[self delegate] respondsToSelector:@selector(dragReceivedWithTrack:)]) {
		return ([[self delegate] dragReceivedWithTrack:track]);
	}
		
	return NO;
}

- (void)dealloc
{
    [super dealloc];
}

@end
