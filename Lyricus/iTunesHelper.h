
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface iTunesHelper : NSObject {
	iTunesApplication *iTunes;	
}

-(NSArray *)getAllPlaylists;
-(NSArray *)getSelectedTracks;
-(NSArray *)getAllTracksForTitle:(NSString *)theTitle byArtist:(NSString *)theArtist;
-(NSArray *)getTracksForPlaylist:(NSString *)thePlaylist;
-(iTunesTrack *)getCurrentTrack;
-(NSString *)getLyricsForTrack:(iTunesTrack *)theTrack;
-(BOOL)setLyrics:(NSString *)theLyrics ForTrack:(iTunesTrack *)theTrack;

-(BOOL)isiTunesRunning;
-(iTunesTrack *)getTrackForTitle:(NSString *)theTitle byArtist:(NSString *)theArtist;

-(iTunesApplication *)iTunesReference; // Use sparingly!

-(NSArray *)getAllTracksAndLyrics;

@end
