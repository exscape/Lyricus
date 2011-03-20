
//
// This file is part of Lyricus.
// Copyright (c) 2008, Thomas Backman <serenity@exscape.org>
// All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TBUtil : NSObject {

}

+(NSString *)getHTMLFromURL:(NSURL *)url error:(NSError **)error;
+(NSString *)getHTMLFromURL:(NSURL *)url withCharset:(NSStringEncoding)theEncoding error:(NSError **)error;
+(BOOL) string:(NSString *) string isEqualToString:(NSString *)otherTitle;
+(NSInteger) showAlert:(NSString *) errText withCaption:(NSString *) caption;

@end
