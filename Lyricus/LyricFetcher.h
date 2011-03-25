//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SitePriorities.h"
#import "TBSongmeanings.h"
#import "TBDarklyrics.h"
#import "TBAZLyrics.h"

@interface LyricFetcher : NSObject {
	NSMutableArray *sitesByPriority;
}

@property (readonly) NSMutableArray *sitesByPriority;

// Our face outwards
-(NSString *)fetchLyricsForTrack:(NSString *)theTrack byArtist:(NSString *)theArtist error:(NSError **)error;

-(void) updateSiteList;

@end
