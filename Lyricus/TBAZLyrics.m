//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "TBAZLyrics.h"
#import "NSString+ExscapeEdits.h"

@implementation TBAZLyrics

-(TBAZLyrics *) init {
    self = [super init];
	if (self) {
		return self;
	}
	return nil;
}

#pragma mark -
#pragma mark Public

-(NSString *) fetchLyricsForTrack:(NSString *)title byArtist:(NSString *)artist withBatch:(BOOL)batch error:(NSError **)error {
	//
	// The only method called from the outside
	//
	if (!batch) [self sendStatusUpdate:@"Trying AZLyrics..." ofType:LyricusNoteHeader];
	
	if (!batch) [self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteStartedWorking];

	NSString *artistURL = [self getURLForArtist:artist error:error];
	if (artistURL == nil) {
		if (!batch)[self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteFailure];
		return nil;
	}
	else
		if (!batch) [self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteSuccess];

	if (!batch) [self sendStatusUpdate:@"Searching for lyric page..." ofType:LyricusNoteStartedWorking];
	NSString *trackURL = [self getLyricURLForTrack:title fromArtistURL: artistURL error:error];
	if (trackURL == nil) {
		if (!batch) [self sendStatusUpdate:@"Searching for lyric page..." ofType:LyricusNoteFailure];
		return nil;
	}
	else
		if (!batch) [self sendStatusUpdate:@"Searching for lyric page..." ofType:LyricusNoteSuccess];
	
	if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteStartedWorking];
	NSString *lyrics = [self extractLyricsFromURL:trackURL forTrack:title error:error];
    
	if (lyrics == nil || [lyrics length] < 5) {
		return nil;
		if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteFailure];
	}
	else {
		if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteSuccess];
        return lyrics;
	}
}

#pragma mark -
#pragma mark Internal/private

-(NSString *)getURLForArtist:(NSString *) inArtist error:(NSError **)error {
	NSString *artist = [inArtist stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	artist = [artist stringByAddingPercentEscapesUsingEncoding:NSISOLatin1StringEncoding];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://search.azlyrics.com/search.php?q=%@", artist]];

	NSError *err = nil;
	NSString *html = [TBUtil getHTMLFromURLUsingUTF8:url error:&err];
	if (html == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
    }
	
	NSString *regex =
	@"<a href=\"(http://www.azlyrics.com/\\w/[^.]*\\.html)\" rel=\"external\"><b>.*? lyrics</b>";
	// CASE SENSITIVE, as "BAND lyrics" is the right link ("BAND LYRICS - <song name>" is not.)
	
	NSString *artistURL = [html stringByMatching:regex capture:1L];	
	return artistURL;	
}

-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSString *)inURL error:(NSError **)error {
	//
	// Looks through an artist page (i.e. "http://www.azlyrics.com/d/darktranquillity.html") for the track link
	//
	NSURL *artistURL = [NSURL URLWithString:inURL];
    NSError *err = nil;
	NSString *html = [TBUtil getHTMLFromURLUsingUTF8:artistURL error:&err];
	if (html == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
    }
    
	NSString *regex = 
    @"<a href=\"(../lyrics/[^\"]*)\" target=\"_blank\">(.*?)</a><br[^>]*>";
	
    NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"url", 1, @"title", 2, nil];
    for (NSDictionary *match in matchArray) {
		if ([TBUtil string:title isEqualToString:[match objectForKey:@"title"]]) // we ignore all non-chars, so that "The Serpent's chalice" matches "the Serpents chalice" and so on.
            return [[match objectForKey:@"url"] stringByReplacingOccurrencesOfRegex:@"^\\.\\./lyrics/" withString:@"http://www.azlyrics.com/lyrics/"];
	}
	return nil;
}

-(NSString *)extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName error:(NSError **)error {
	//
	// Extracts and returns the lyrics from a given URL and trackname.
	//
	if (url == nil)
		return nil;
	
	NSString *source;
    NSError *err = nil;
    source = [TBUtil getHTMLFromURLUsingUTF8:[NSURL URLWithString:url] error:&err];
	
	if (source == nil) {
        if (err != nil) {
            NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
            [errorDetail setValue:@"Unable to download lyrics. This could be a problem with your internet connection or the site(s) used." forKey:NSLocalizedDescriptionKey];
            if (error != nil) {
                *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusHTMLFetchError userInfo:errorDetail];
            }
        }
        return nil;
    }

	NSString *regex = 
	@"<!-- start of lyrics -->([\\s\\S]*?)<!-- end of lyrics -->";
    
    NSMutableString *lyrics = [[source stringByMatching:regex capture:1L] mutableCopy];

    [lyrics replaceOccurrencesOfRegex:@"<[^>]*>" withString:@""];
    if (lyrics && ![lyrics isEqual:@""]) {
        return [lyrics stringByTrimmingWhitespace];
    }
    
	// If we've checked all titles, something is wrong, since AZLyrics provides a list of the lyrics supported to be at this URL. This is likely because the regular expression doesn't match due to site updates.
    
    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
    [errorDetail setValue:@"Unable to parse lyrics. Please report this to the developer at serenity@exscape.org!" forKey:NSLocalizedDescriptionKey];
    if (error != nil) {
        *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusLyricParseError userInfo:errorDetail];
    }
    return nil;
}

@end
