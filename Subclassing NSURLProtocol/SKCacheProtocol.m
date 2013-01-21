/*
    SKCacheProtocol
 */

#import "SKCacheProtocol.h"

#define TRACE()  fprintf(stdout, "%s\n", [NSStringFromSelector(_cmd) UTF8String]);
NSString *const MyHTTPHeader;
NSString *const kResponseKey;
NSString *const kCachedLocationKey;
NSString *const kObjectKey;
NSString *const kDataKey;


/* ------------------------ SKCache Object ------------------------ */
@interface SKCache:NSObject<NSCoding>
    @property(nonatomic, strong) NSData *data;
    @property(nonatomic, strong) NSURLResponse *response;
    @property(nonatomic, strong) NSString *cachedLocation;
    -(id)initWithResponse:(NSURLResponse*)response data:(NSData*)data cacheLocation:(NSString*)path;
    -(void)save;
    +(SKCache*)cacheAtPath:(NSString*)path;
@end

/* -------------------------------------------------------------- */


@interface SKCacheProtocol()<NSURLConnectionDataDelegate, NSURLConnectionDelegate>
    @property(nonatomic, strong) NSURLConnection *connection;
    @property(nonatomic, strong) NSURLResponse *response;
    @property(nonatomic, strong) NSMutableData *data;
    @property(nonatomic, strong) NSURLRequest *request;
@end



@implementation SKCacheProtocol

-(id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client{
    NSMutableURLRequest *myRequest = [request mutableCopy];
    [myRequest setValue:@"" forHTTPHeaderField:MyHTTPHeader]; // set any header
    self = [super initWithRequest:myRequest cachedResponse:cachedResponse client:client];
    if(self){
        [self setRequest:myRequest];
        TRACE();
    }
    return self;
}

+(BOOL)canInitWithRequest:(NSURLRequest *)request{
    // the same request can again come to ask this method so check if the request is already
    // initialized using the headerfield assigned in initWithRequest:
    TRACE();
    if([request valueForHTTPHeaderField:MyHTTPHeader] == nil)
        return YES;
    return NO;
}

// do additional mofication to the request with additional headers
+(NSURLRequest*)canonicalRequestForRequest:(NSURLRequest *)request{
      TRACE();
    return request;
}

// when setup is done this method is called
-(void)startLoading{
      TRACE();
    NSString *path = [self cachedLocationForURLRequest:self.request];
    SKCache *cache = [SKCache cacheAtPath:path];
    if(cache != nil){
        [[self client] URLProtocol:self didReceiveResponse:cache.response cacheStoragePolicy:NSURLCacheStorageAllowed];
        [[self client] URLProtocol:self didLoadData:cache.data];
        [[self client] URLProtocolDidFinishLoading:self];
    }else{
        self.data = [NSMutableData data];
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self];
    }
}

// when finished the connection or cancelled by other means
-(void)stopLoading{
      TRACE();
    [self.connection cancel];
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
      TRACE();
    [self.data setLength:0];
    self.response = response;
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
      TRACE();
    [[self client] URLProtocol:self didFailWithError:error];
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
      TRACE();
    [self.data appendData:data];
    [[self client] URLProtocol:self didLoadData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection{
    TRACE();
    [[self client] URLProtocolDidFinishLoading:self];
    SKCache *cache = [[SKCache alloc] init];
    cache.response = self.response;
    cache.cachedLocation = [self cachedLocationForURLRequest:self.request];
    cache.data = self.data;
    [cache save];
}

-(NSString*)cachedLocationForURLRequest:(NSURLRequest*)request{
    TRACE();
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"Caches"];
    static BOOL directoryExist = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = YES;
    if(!directoryExist){
        if( ![fileManager fileExistsAtPath:path isDirectory:&isDirectory]){
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    directoryExist = YES;
    path = [path stringByAppendingFormat:@"/%x",[[[self.request URL] absoluteString] hash]];
    return path;
}

@end



@implementation SKCache

-(id)initWithResponse:(NSURLResponse *)response data:(NSData *)data cacheLocation:(NSString *)path{
    if(self = [super init]){
        self.response = response;
        self.data = data;
        self.cachedLocation = path;
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    if(self = [super init]){
        self.data = [aDecoder decodeObjectForKey:kDataKey];
        self.response = [aDecoder decodeObjectForKey:kResponseKey];
        self.cachedLocation = [aDecoder decodeObjectForKey:kCachedLocationKey];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder{
    [aCoder encodeObject:self.data forKey:kDataKey];
    [aCoder encodeObject:self.response forKey:kResponseKey];
    [aCoder encodeObject:self.cachedLocation forKey:kCachedLocationKey];
}

-(void)save{
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver encodeObject:self forKey:kObjectKey];
    [archiver finishEncoding];
    [data writeToFile:self.cachedLocation atomically:YES];
}

+(SKCache*)cacheAtPath:(NSString*)path{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:[NSData dataWithContentsOfFile:path]];
    SKCache *cache = [unarchiver decodeObjectForKey:kObjectKey];
    [unarchiver finishDecoding];
    return cache;
}

@end

NSString *const kDataKey = @"kDataKey";
NSString *const kResponseKey = @"kResponseKey";
NSString *const kCachedLocationKey = @"kCachedLocationKey";
NSString *const kObjectKey = @"SKCache";
NSString *const MyHTTPHeader = @"SKHeader";
