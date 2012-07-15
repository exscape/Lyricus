//
// This file is part of Lyricus.
// Copyright (c) 2008-2011, Thomas Backman <serenity@exscape.org>
// This software is distributed under the terms of the MIT license. For details, see license.txt.
//

#import "TBDarklyrics.h"
#import "NSString+ExscapeEdits.h"

@implementation TBDarklyrics

-(TBDarklyrics *) init {
    self = [super init];
	if (self) {
		albumCache = [[NSMutableDictionary alloc] init];
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
	if (!batch) [self sendStatusUpdate:@"Trying darklyrics..." ofType:LyricusNoteHeader];

	if (!batch) [self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteStartedWorking];
	NSURL *artistURL = [self getURLForArtist:artist];
	if (artistURL == nil) {
		if (!batch) [self sendStatusUpdate:@"Searching for artist page..." ofType:LyricusNoteFailure];
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
		if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteFailure];
		return nil;
	}
	else {
		if (!batch) [self sendStatusUpdate:@"Downloading lyrics..." ofType:LyricusNoteSuccess];
        return lyrics;
	}
}

#pragma mark -
#pragma mark Internal/private

-(NSString *)getURLForArtist:(NSString *) artist /* cannot fail, so no &error */ {
	// Easy enough, all URLs seem to be in the form "http://www.darklyrics.com/t/theartistnamegoeshere.html"
	
	// First, make the artist name lowercase and remove all non-chars
	artist = [[[artist lowercaseString] stringByStrippingNonCharacters]
			  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	if (artist == nil || [artist length] < 1)
		return nil;
	
	// Then, create the URL and return it.
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://www.darklyrics.com/%c/%@.html", [artist characterAtIndex:0], artist]];
}

-(NSString *)getLyricURLForTrack:(NSString *)title fromArtistURL:(NSURL *)artistURL error:(NSError **)error {
	//
	// Looks through an artist page (i.e. "http://www.darklyrics.com/d/darktranquillity.html") for the track link
	//
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
	@"<a href=\"../([^#]*?)\\#\\d+\">([^<]*?)</a><br[^>]*>";
	
    NSArray *matchArray = [html arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"url", 1, @"title", 2, nil];
    for (NSDictionary *match in matchArray) {
		if ([TBUtil string:title isEqualToString:[match objectForKey:@"title"]]) // we ignore all non-chars, so that "The Serpent's chalice" matches "the Serpents chalice" and so on.
            return [[match objectForKey:@"url"] stringByReplacingOccurrencesOfRegex:@"^lyrics/" withString:@"http://www.darklyrics.com/lyrics/"];
	}
	return nil;
}

-(NSString *)extractLyricsFromURL:(NSString *)url forTrack:(NSString *)trackName error:(NSError **)error {
	//
	// Extracts and returns the lyrics from a given URL and trackname.
	//
	if (url == nil)
		return nil;
	
	// This cache is only used for the session, and means that instead of re-downloading the lyrics for an album
	// 10 times for 10 tracks, we'll only download it once. The cache is NOT saved between sessions, which also shouldn't be necessary.
	// (Darklyrics displays the lyrics for ALL tracks an on album on the same page, so fetching it 10 times for 10 tracks is just stupid.)
	NSString *source;
    NSError *err = nil;
	if ([albumCache objectForKey:url] != nil) {
		source = [albumCache objectForKey:url];
	}
	else {
		source = [TBUtil getHTMLFromURLUsingUTF8:[NSURL URLWithString:url] error:&err];
		if (source)
			[albumCache setObject:source forKey:url];
	}
	
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
	
	NSMutableString *lyrics;
	NSString *regex = 
	@"(?i)<h3><a name=\"\\d+\">\\d+\\. ([^<]*?)</a></h3><br />\\s*([\\s\\S]+?)(?=<br /><br />)";
    // Ah, the beauty of regular expressions.

    NSArray *matchesArray = [source arrayOfDictionariesByMatchingRegex:regex withKeysAndCaptures:@"title", 1, @"lyrics", 2, nil];
    
    for (NSDictionary *match in matchesArray) {
		if ([TBUtil string:[match objectForKey:@"title"] isEqualToString:trackName]) {
            lyrics = [[match objectForKey:@"lyrics"] mutableCopy];
            [lyrics replaceOccurrencesOfRegex:@"<[^>]*>" withString:@""];
			
			return [lyrics stringByTrimmingWhitespace];
		}
	}
    
	// If we've checked all titles, something is wrong, since darklyrics provides a list of the lyrics supported to be at this URL. This is likely because the regular expression doesn't match due to site updates.

    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
    [errorDetail setValue:@"Unable to parse lyrics at darklyrics. Please report this to the developer at serenity@exscape.org!" forKey:NSLocalizedDescriptionKey];
    if (error != nil) {
        *error = [NSError errorWithDomain:@"org.exscape.Lyricus" code:LyricusLyricParseError userInfo:errorDetail];
    }
    return nil;
}

@end
