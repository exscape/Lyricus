
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TBSongmeanings : NSObject {
	TBUtil *util;
}

//
// Sorted by order of invocation
//
-(NSMutableArray *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist;

// Private methods
-(NSString *)getURLForArtist:(NSString *) artist;
-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL;
-(NSString *)extractLyricsFromURL:(NSString *)url;

@end
