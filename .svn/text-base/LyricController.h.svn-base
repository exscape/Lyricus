
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SitePriorities.h"
#import "TBSongmeanings.h"
#import "TBDarklyrics.h"
//#import "TBLyricwiki.h"

@interface LyricController : NSObject {
	NSMutableArray *sitesByPriority;
}

@property (readonly) NSMutableArray *sitesByPriority;

// Our face outwards
-(NSMutableArray *)fetchDataForTrack:(NSString *)theTrack byArtist:(NSString *)theArtist;

-(void) updateSiteList;

@end
