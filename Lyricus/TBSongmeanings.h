
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
-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist error:(NSError **)error;

// Private methods
-(NSString *)getURLForArtist:(NSString *) artist error:(NSError **)error;
-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)artistURL error:(NSError **)error;
-(NSString *)extractLyricsFromURL:(NSString *)url error:(NSError **)error;

@end
