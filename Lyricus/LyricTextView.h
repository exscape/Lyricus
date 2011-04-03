//
//  LyricTextView.h
//  Lyricus
//
//  Created by Thomas Backman on 4/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface LyricTextView : NSTextView {
}

@end

@interface NSObject (LyricusDragging)
-(BOOL)dragReceivedWithTrack:(NSDictionary *)track;
@end
