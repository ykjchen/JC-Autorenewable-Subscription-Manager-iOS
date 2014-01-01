//
//  JCLegacyReceiptVerifier.m
//  SubscriptionManager
//
//  Created by Joseph Chen on 12/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

#import "JCLegacyReceiptVerifier.h"

// Configuration
#import "JCSubscriptionManager.h"
#import "JCSubscriptionManagerConfigs.h"

// Base64 Conversion
#import "NSData+Base64.h"

// Internet reachability
#import "Reachability.h"

// Keychain storage
#import "Lockbox.h"

@interface JCLegacyReceiptVerifier ()

@property (strong, nonatomic) NSDictionary *reachabilities;
@property (strong, nonatomic) NSMutableArray *receiptsAwaitingVerification;
@property (strong, nonatomic) NSMutableArray *receiptsBeingVerified;
@property (strong, nonatomic) NSTimer *verificationRetryTimer;

@end

// If an error is encountered during verification,
// the verifier will retry verification this many seconds later.
NSTimeInterval const kVerificationRetryInterval = 15.0;
NSString *const kLockboxLatestReceiptKey = @"latest-receipt";

@implementation JCLegacyReceiptVerifier

- (void)dealloc
{
    // In case the timer is still going.
    if (_verificationRetryTimer) {
        [_verificationRetryTimer invalidate];
        _verificationRetryTimer = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setUpReachabilities];
    }
    return self;
}

#pragma mark - Keychain Storage

+ (NSData *)latestReceipt
{
    NSString *dataString = [Lockbox stringForKey:kLockboxLatestReceiptKey];
    if (!dataString) {
        return nil;
    }
    
    return [dataString dataUsingEncoding:NSUTF8StringEncoding];
}

+ (BOOL)setLatestReceipt:(NSData *)receipt
{
    if (!receipt) {
        return [Lockbox setString:nil forKey:kLockboxLatestReceiptKey];
    }
    
    NSString *dataString = [[NSString alloc] initWithData:receipt encoding:NSUTF8StringEncoding];
    return [Lockbox setString:dataString forKey:kLockboxLatestReceiptKey];
    
}

#pragma mark - Reachability

- (void)setUpReachabilities
{
    if (self.reachabilities) {
        return;
    }
    
    NSArray *servers = [self verificationServers];
    NSMutableDictionary *reachabilities = [NSMutableDictionary dictionaryWithCapacity:servers.count];
    for (NSString *server in servers) {
        Reachability *reachability = [Reachability reachabilityWithHostName:[server hostName]];
        [reachabilities setObject:reachability forKey:server];
        [reachability startNotifier];
    }
    self.reachabilities = [NSDictionary dictionaryWithDictionary:reachabilities];
}

#pragma mark - Verification Server

- (NSArray *)verificationServers
{
    return [NSArray arrayWithObjects:OWN_VERIFICATION_SERVER, APPLE_VERIFICATION_SERVER, nil];
}

- (NSString *)verificationServer
{
    for (NSString *server in [self verificationServers]) {
        Reachability *reachability = [self.reachabilities objectForKey:server];
        if (reachability.currentReachabilityStatus != NotReachable) {
            return server;
        } else {
            JCLog(@"%@ is unreachable.", server);
        }
    }
    return nil;
}

- (BOOL)isAppleServer:(NSURL *)url
{
    return [url.path isEqualToString:APPLE_VERIFICATION_SERVER];
}

#pragma mark - Tracking Verification Jobs

- (NSMutableArray *)receiptsAwaitingVerification
{
    if (!_receiptsAwaitingVerification) {
        _receiptsAwaitingVerification = [[NSMutableArray alloc] init];
    }
    return _receiptsAwaitingVerification;
}

- (NSMutableArray *)receiptsBeingVerified
{
    if (!_receiptsBeingVerified) {
        _receiptsBeingVerified = [[NSMutableArray alloc] init];
    }
    return _receiptsBeingVerified;
}

- (BOOL)isReceiptBeingVerified:(NSData *)receipt
{
    return [self.receiptsBeingVerified containsObject:receipt];
}

#pragma mark - Set up URL Connection

- (JCURLConnection *)urlConnectionForUrl:(NSURL *)url receipt:(NSData *)receipt
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:60];
	
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	
    NSString *receiptDataString = [receipt base64EncodedString];
    
    NSString *postDataString;
    if ([self isAppleServer:url]) {
        postDataString = [NSString stringWithFormat:@"{\"receipt-data\":\"%@\" \"password\":\"%@\"}", receiptDataString, AUTORENEWABLE_SUBSCRIPTION_SHARED_SECRET];
    } else {
        postDataString = [NSString stringWithFormat:@"receipt-data=%@&sandbox=%i", receiptDataString, SANDBOX_MODE];
    }
    
	NSString *length = [NSString stringWithFormat:@"%lu", (unsigned long)[postDataString length]];
	[request setValue:length forHTTPHeaderField:@"Content-Length"];
	
	[request setHTTPBody:[postDataString dataUsingEncoding:NSASCIIStringEncoding]];
	
    JCURLConnection *urlConnection = [[JCURLConnection alloc] initWithRequest:request
                                                                     delegate:self];
    urlConnection.receipt = receipt;
    return urlConnection;
}

#pragma mark - Timer

- (void)startVerificationRetryTimer
{
    if (self.verificationRetryTimer) {
        return;
    }
    
    self.verificationRetryTimer = [NSTimer scheduledTimerWithTimeInterval:kVerificationRetryInterval
                                                              target:self
                                                            selector:@selector(retryVerification)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)retryVerification
{
    // make sure there are receipts waiting to be verified
    if (self.receiptsAwaitingVerification.count == 0) {
        [self.verificationRetryTimer invalidate];
        self.verificationRetryTimer = nil;
        return;
    }
    
    // verify each receipt
    for (NSData *receipt in [NSArray arrayWithArray:self.receiptsAwaitingVerification]) {
        [self verifyReceipt:receipt];
    }
}

#pragma mark - Public

- (void)verifyLatestReceipt
{
    NSData *latestReceipt = [self.class latestReceipt];

    if (!latestReceipt) {
        if (self.delegate && [self.delegate conformsToProtocol:@protocol(JCReceiptVerifierDelegate)] && [self.delegate respondsToSelector:@selector(receiptVerifier:verifiedExpiration:)]) {
            [self.delegate receiptVerifier:self
                        verifiedExpiration:nil];
        }
        return;
    }
    
    [self verifyReceipt:latestReceipt];
}

- (void)verifyReceipt:(NSData *)receipt
{
    // add to queue (in case something keeps verification from happening)
    if (![self.receiptsAwaitingVerification containsObject:receipt]) {
        [self.receiptsAwaitingVerification addObject:receipt];
    }

    // check if any verification server is available
    NSString *server = [self verificationServer];
    if (server == nil) {
        JCLog(@"Receipt verification postponed... waiting for reachable server.");
        [self startVerificationRetryTimer];
        return;
    }

    // check if receipt is already being verified
    if ([self isReceiptBeingVerified:receipt]) {
        return;
    }
    
    // start url connection
    NSURL *url = [NSURL URLWithString:server];
    JCURLConnection *urlConnection = [self urlConnectionForUrl:url receipt:receipt];
    [urlConnection start];
    
    // keep track
    [self.receiptsAwaitingVerification removeObject:receipt];
    if (![self.receiptsBeingVerified containsObject:receipt]) {
        [self.receiptsBeingVerified addObject:receipt];
    }
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response
{
    [(JCURLConnection *)connection setData:[NSMutableData data]];
}

- (void)connection:(NSURLConnection *)connection
    didReceiveData:(NSData *)data
{
    [[(JCURLConnection *)connection data] appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (![connection isKindOfClass:[JCURLConnection class]]) {
        JCLog(@"Error: connection is of class: %@", connection.class);
        return;
    }
    
    NSData *receipt = [(JCURLConnection *)connection receipt];
    if (!receipt) {
        JCLog(@"Error: no receipt found for connection. Aborting...");
        return;
    }
    
    [self.receiptsBeingVerified removeObject:receipt];
    
    if (!self.delegate ||
        ![self.delegate conformsToProtocol:@protocol(JCReceiptVerifierDelegate)] ||
        ![self.delegate respondsToSelector:@selector(receiptVerifier:verifiedExpiration:)]) {
        return;
    }

    BOOL usingAppleServer = [(JCURLConnection *)connection usingAppleServer];
    NSData *responseData = [(JCURLConnection *)connection data];
    NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData
                                                             options:NSJSONReadingAllowFragments
                                                               error:nil];

    // get response info
    NSString *statusString = [response objectForKey:@"status"]; // not used yet
    
    NSString *latestReceiptString = [response objectForKey:@"latest_receipt"];
    NSString *expires_date = nil;
    if (!usingAppleServer) {
        // verified receipt with own server
        expires_date = [response objectForKey:@"expires_date"];
    } else {
        // verified receipt directly with apple
        expires_date = [[response objectForKey:@"receipt"] objectForKey:@"expires_date"];
    }

    // convert to desired forms
    NSData *latestReceipt = nil;
    NSNumber *expirationIntervalSince1970 = nil;

    if (expires_date) {
        NSTimeInterval interval = [expires_date doubleValue] / 1000.0; // in milliseconds
        expirationIntervalSince1970 = @(interval);
    }
    
    if (latestReceiptString) {
        latestReceipt = [NSData dataFromBase64String:latestReceiptString];
        [self.class setLatestReceipt:latestReceipt];
        
        NSTimeInterval expirationIntervalInReceipt = [self expirationIntervalFrom1970InReceipt:latestReceipt];
        if (expirationIntervalInReceipt > expirationIntervalSince1970.doubleValue) {
            expirationIntervalSince1970 = @(expirationIntervalInReceipt);
            
            JCLog(@"Found a later expiration interval in latest_receipt: %li", (long)expirationIntervalInReceipt);
        }
    }

    // call delegate
    [self.delegate receiptVerifier:self
                verifiedExpiration:expirationIntervalSince1970];
    
    JCLog(@"Verified receipt with status:%@ expirationInterval:%@ now:%li", statusString, expirationIntervalSince1970, (long)[[NSDate date] timeIntervalSince1970]);
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    JCLog(@"Receipt verification connection failed: %@", error.localizedDescription);
    if (![connection isKindOfClass:[JCURLConnection class]]) {
        JCLog(@"Expected class: JCURLConnection Got class: %@", connection.class);
        return;
    }
    
    NSData *receipt = [(JCURLConnection *)connection receipt];
    if (!receipt) {
        JCLog(@"No receipt found for connection.");
        return;
    }
    
    if (![self.receiptsAwaitingVerification containsObject:receipt]) {
        [self.receiptsAwaitingVerification addObject:receipt];
    }
    [self.receiptsBeingVerified removeObject:receipt];
    
    JCLog(@"Will retry receipt verification in %f seconds.", kVerificationRetryInterval);
    [self startVerificationRetryTimer];
}

// Resources in case you have problems using SSL in verification server.
/*
//http://stackoverflow.com/questions/6307400/load-https-url-in-a-uiwebview
 - (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return YES;
 }
 
 - (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
 }

//http://stackoverflow.com/questions/9122761/ios-5-nsurlconnection-to-https-servers
 - (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSArray *trustedHosts = [NSArray arrayWithObjects:@"mytrustedhost",nil];
 
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        if ([trustedHosts containsObject:challenge.protectionSpace.host]) {
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        }
    }
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
 }
 */

#pragma mark - Receipt Info

- (NSTimeInterval)expirationIntervalFrom1970InReceipt:(NSData *)receipt
{
    if (!receipt) {
        return 0.0;
    }
    
    NSDictionary *receiptDict = [receipt plistDictionary];
    NSString *base64EncodedPurchaseInfo = [receiptDict objectForKey:@"purchase-info"];
    NSData *decodedPurchaseData = [NSData dataFromBase64String:base64EncodedPurchaseInfo];

    NSDictionary *purchaseInfo = [decodedPurchaseData plistDictionary];
    NSNumber *expires_date = [purchaseInfo objectForKey:@"expires-date"];
    if (!expires_date) {
        JCLog(@"Value not found for expires_date.");
        return 0.0;
    }
    
    NSTimeInterval expirationInterval = [expires_date doubleValue] / 1000.0; // value is in milliseconds
    return expirationInterval;
}

#pragma mark - Testing

- (void)clearPurchaseInfo
{
    [self.class setLatestReceipt:nil];
}

@end

#pragma mark - JCURLConnection

@implementation JCURLConnection

@end

@implementation NSString (JCLegacyReceiptVerifier)

- (NSString *)hostName
{
    NSRange startRange = [self rangeOfString:@"://"];
    NSInteger startLocation = startRange.location;
    if (startLocation == NSNotFound) {
        startLocation = 0;
    }
    NSInteger hostStartLocation = startLocation + startRange.length;
    NSInteger endLocation = [self rangeOfString:@"/"
                                        options:0
                                          range:NSMakeRange(hostStartLocation, self.length - hostStartLocation)].location;
    if (endLocation == NSNotFound) {
        endLocation = self.length;
    }
    
    return [self substringWithRange:NSMakeRange(hostStartLocation, endLocation - hostStartLocation)];
}

@end

@implementation NSData (JCLegacyReceiptVerifier)

- (NSDictionary *)plistDictionary
{
    NSError *error;
    NSDictionary *parsedDictionary = [NSPropertyListSerialization propertyListWithData:self
                                                                               options:NSPropertyListImmutable
                                                                                format:nil
                                                                                 error:&error];
    if (!parsedDictionary)
    {
        JCLog(@"Couldn't convert data to plist: %@", error.localizedDescription);
        return nil;
    }
    
    return parsedDictionary;
}

@end