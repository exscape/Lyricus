
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import "TBUtil.h"
#import "NSString+ExscapeEdits.h"

@implementation TBUtil

+(NSInteger) showAlert:(NSString *) informativeText withCaption:(NSString *) caption {
	// Shows an alert, pure and simple. Not just for error messages, despite the method names.
	return [[NSAlert alertWithMessageText:caption defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:informativeText]
	 runModal];
}

+(BOOL) string:(NSString *) string isEqualToString:(NSString *)otherString
{
	//
	// Compares two track titles, ignoring everything but actual characters, and also ignoring "the" and diacritics (üàñ etc).
	//
	
	if (string == nil || otherString == nil)
		return NO;

	NSString *t1 = [[string 		stringByReplacingOccurrencesOfString:@"The" withString:@"" options:(NSCaseInsensitiveSearch+NSWidthInsensitiveSearch) range:NSMakeRange(0, [string length])] stringByStrippingNonCharacters];
	NSString *t2 = [[otherString stringByReplacingOccurrencesOfString:@"The" withString:@"" options:(NSCaseInsensitiveSearch+NSWidthInsensitiveSearch) range:NSMakeRange(0, [otherString length])] stringByStrippingNonCharacters];
	return ( [t1 compare:t2 options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)] == NSOrderedSame );
}

+(NSString *)getHTMLFromURL:(NSURL *)url {
	return [self getHTMLFromURL:url withCharset:NSISOLatin1StringEncoding];
}

+(NSString *)getHTMLFromURL:(NSURL *)url withCharset:(NSStringEncoding)theEncoding {
	//
	// Quick, dirty, no-error-checking fetching of an URL
	//
	NSData *data = [NSData dataWithContentsOfURL:url];
	if (data == nil)
		return nil;
	
	return [[NSString alloc] initWithData:data encoding:theEncoding];
}

@end
