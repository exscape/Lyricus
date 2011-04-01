//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "TrackObject.h"

@implementation TrackObject

@synthesize track;
@synthesize artist;
@synthesize name;
@synthesize state;
@synthesize processed;

-(void)setState:(NSInteger)inState {
	
	// If the state is CHANGED to either of these two values,
	// the batch downloader has tried to fetch lyrics,
	// and either succeeded or failed.
	// If the state is NSMixedState, it's still in progress,
	// so don't update the processed property.
	if (inState == NSOnState || inState == NSOffState)
		processed = YES;
	
	state = inState;
}

- (id)init {
	return nil;
}

- (id)initWithTrack:(iTunesTrack*)tr Artist:(NSString *)inArtist Name:(NSString *)inName {
	self = [super init];
	if (self) {
		track = tr;
		name = inName;
		artist = inArtist;
		state = 0; /* allows mixed state, (-1, 0 or 1) */
		processed = NO; /* has this track been processed? */
	}
	
	return self;
}

-(NSString *)description {
	return name;
}

- (void)dealloc {
    [super dealloc];
}

@end