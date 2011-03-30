//
//  RootLevelObject.h
//  NSOutlineView
//
//  Created by Thomas Backman on 3/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
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