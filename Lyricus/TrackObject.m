#import "TrackObject.h"


@implementation TrackObject

@synthesize track;
@synthesize artist;
@synthesize name;
@synthesize processed;

- (id)init {
	return nil;
}

- (id)initWithTrack:(iTunesTrack*)tr Artist:(NSString *)inArtist Name:(NSString *)inName {
	self = [super init];
	if (self) {
		track = tr;
		name = inName;
		artist = inArtist;
		processed = NO;
	}
	
	return self;
}

-(NSString *)description {
	return name;
}

- (void)dealloc {
    [super dealloc];
}

@end