//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import <Foundation/Foundation.h>
#import "iTunes.h"

@interface TrackObject : NSObject {
	iTunesTrack *track;
	NSString *artist;
	NSString *name;
	NSInteger state;
	BOOL processed;
    
}
- (id)initWithTrack:(iTunesTrack*)tr Artist:(NSString *)inArtist Name:(NSString *)inName;

@property (retain, readonly) iTunesTrack *track;
@property (retain, readonly) NSString *artist;
@property (retain, readonly) NSString *name;
@property NSInteger state;
@property BOOL processed;

@end