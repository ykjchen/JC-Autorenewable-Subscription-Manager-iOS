//
//  JCStoreKitHelper.m
//  SubscriptionManager
//
//  Created by Joseph Chen on 12/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

#import "JCStoreKitHelper.h"

#import "JCSubscriptionManager.h"

// config
#import "JCSubscriptionManagerConfigs.h"

// reachability
#import "Reachability.h"

@interface JCStoreKitHelper () <SKProductsRequestDelegate>

@property (strong, nonatomic) NSArray *products;
@property (strong, nonatomic) SKProductsRequest *productsRequest;
@property (strong, nonatomic) NSTimer *productsRequestRetryTimer;

@property (strong, nonatomic) Reachability *internetReachability;

@property (strong, nonatomic) void (^onPurchaseCompletion) (BOOL, NSError *);
@property (strong, nonatomic) void (^onRestoreCompletion) (BOOL, NSError *);

@end

NSTimeInterval kProductRequestRetryInterval = 60.0;

@implementation JCStoreKitHelper

- (void)dealloc
{
    // In case there was a timer running.
    if (_productsRequestRetryTimer) {
        [_productsRequestRetryTimer invalidate];
        _productsRequestRetryTimer = nil;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
        // Internet reachability
        self.internetReachability = [Reachability reachabilityForInternetConnection];
        [self.internetReachability startNotifier];
    }
    return self;
}

+ (NSArray *)productIdentifiers
{
    NSArray *identifiers = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ProductIdentifiers" ofType:@"plist"]];
    return identifiers;
}

- (BOOL)isInternetReachable
{
    return (self.internetReachability.currentReachabilityStatus != NotReachable);
}

#pragma mark - Making Purchases

- (BOOL)addProductToPaymentQueue:(NSString *)productId
{
    if ([SKPaymentQueue canMakePayments]) {
        NSInteger productIndex = [self.products indexOfObjectPassingTest:^BOOL(SKProduct *obj, NSUInteger idx, BOOL *stop)
                                  {
                                      if ([obj.productIdentifier isEqualToString:productId]) {
                                          *stop = YES;
                                          return YES;
                                      }
                                      return NO;
                                  }];

        if (productIndex == NSNotFound) {
            JCLog(@"Product %@ was not retrieved and cannot be added to SKPaymentQueue.", productId);
            return NO;
        }
        
        SKProduct *product = [self.products objectAtIndex:productIndex];
        if (!product) {
            return NO;
        }
        
		SKPayment *payment = [SKPayment paymentWithProduct:product];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
        
        return YES;
	} else {
        JCLog(@"Could not add product to SKPaymentQueue because IAP is disabled in Settings.");
        return NO;
	}
}

#pragma mark - Public

- (BOOL)requestProductData
{
    // Abort if products already exist.
    if (self.products.count != 0) {
        return NO;
    }
    
    // Abort if request is already running.
    if (self.productsRequest) {
        return NO;
    }
    
    // Abort if no internet.
    if (self.internetReachability.currentReachabilityStatus == NotReachable) {
        return NO;
    }
    
    NSArray *productIdentifiers = [self.class productIdentifiers];
	self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
	self.productsRequest.delegate = self;
	[self.productsRequest start];
    
    JCLog(@"Requesting information for products with identifiers: %@.", [productIdentifiers componentsJoinedByString:@", "]);
    return YES;
}

- (BOOL)buyProductWithIdentifier:(NSString *)productIdentifier
                      completion:(void (^)(BOOL, NSError *))completion
{
    if (self.onPurchaseCompletion || self.onRestoreCompletion) {
        JCLog(@"Could not buy product because another transaction is in progress.");
        return NO;
    }

    if (![self isInternetReachable]) {
        JCLog(@"Could not buy product because internet is not reachable.");
        return NO;
    }

    if (completion) {
        self.onPurchaseCompletion = completion;
    }
    
    BOOL addedToPaymentQueue = [self addProductToPaymentQueue:productIdentifier];
    
    if (!addedToPaymentQueue) {
        self.onPurchaseCompletion = nil;
    }
    
    return addedToPaymentQueue;
}

- (BOOL)restorePreviousTransactionsWithCompletion:(void (^)(BOOL, NSError *))completion
{
    if (self.onPurchaseCompletion || self.onRestoreCompletion) {
        JCLog(@"Could not restore purchases because another transaction is in progress.");
        return NO;
    }
    
    if (![self isInternetReachable]) {
        JCLog(@"Could not restore purchases because internet is not reachable.");
        return NO;
    }
    
    if (completion) {
        self.onRestoreCompletion = completion;
    }
    
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];

    return YES;
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    if (request != self.productsRequest) {
        return;
    }
    self.productsRequest = nil;

    // Sort products by their identifiers and save them.
    // Access through [[JCSubscriptionManager sharedManager] products];
    NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"productIdentifier" ascending:YES];
    NSArray *descriptors = [NSArray arrayWithObject:descriptor];
    self.products = [response.products sortedArrayUsingDescriptors:descriptors];
	
#if LOGGING_ENABLED
    for (NSString *productIdentifier in [self.products valueForKey:@"productIdentifier"]) {
        JCLog(@"Received information for product identifier: %@.", productIdentifier);
    }
    
    if (response.invalidProductIdentifiers.count != 0) {
        JCLog(@"Invalid product identifiers detected: %@. Verify that ProductIdentifiers.plist contains valid identifiers.", [response.invalidProductIdentifiers componentsJoinedByString:@", "]);
    }
#endif
    
    // Send out notification.
    [[NSNotificationCenter defaultCenter] postNotificationName:JCProductDataWasFetchedNotification
                                                        object:nil];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    if (request == self.productsRequest) {
        self.productsRequest = nil;

        JCLog(@"Products request failed with error: %@", error.localizedDescription);
        
        // Try again later
        if (self.productsRequestRetryTimer) {
            [self.productsRequestRetryTimer invalidate];
        }
        self.productsRequestRetryTimer = [NSTimer scheduledTimerWithTimeInterval:kProductRequestRetryInterval
                                                                          target:self
                                                                        selector:@selector(requestProductData)
                                                                        userInfo:nil
                                                                         repeats:NO];
    }
}

- (void)requestDidFinish:(SKRequest *)request
{
    if (request == self.productsRequest) {
        self.productsRequest = nil;
    }
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	for (SKPaymentTransaction *transaction in transactions)
	{
		switch (transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
                [self purchaseTransactionCompleted:transaction];
                break;
				
            case SKPaymentTransactionStateFailed:
                [self transactionFailed:transaction];
                break;
				
            case SKPaymentTransactionStateRestored:
                [self restoreTransactionCompleted:transaction];
                break;
				
            default:
                break;
		}
	}
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    if (self.onRestoreCompletion) {
        self.onRestoreCompletion(YES, nil);
        self.onRestoreCompletion = nil;
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    if (self.onRestoreCompletion) {
        self.onRestoreCompletion(NO, error);
        self.onRestoreCompletion = nil;
    }
}

- (void)transactionFailed:(SKPaymentTransaction *)transaction
{
    JCLog(@"Failed transaction: %@\nwith error: %@", transaction.description, transaction.error);
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    if (self.onPurchaseCompletion)
    {
        self.onPurchaseCompletion(NO, transaction.error);
        self.onPurchaseCompletion = nil;
    } else if (self.onRestoreCompletion) {
        self.onRestoreCompletion(NO, transaction.error);
        self.onRestoreCompletion = nil;
    }
}

#pragma mark Purchase and Restore

- (void)purchaseTransactionCompleted:(SKPaymentTransaction *)transaction
{
    [self provideContentForTransaction:transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];

    // callback
    if (self.onPurchaseCompletion) {
        self.onPurchaseCompletion(YES, nil);
        self.onPurchaseCompletion = nil;
    }
}

- (void)restoreTransactionCompleted:(SKPaymentTransaction *)transaction
{
	[self provideContentForTransaction:transaction];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
    JCLog(@"Restored %@", transaction.payment.productIdentifier);
}

- (void)provideContentForTransaction:(SKPaymentTransaction *)transaction
{
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(JCStoreKitHelperDelegate)] && [self.delegate respondsToSelector:@selector(storeKitHelper:didCompleteTransaction:)]) {
        [self.delegate storeKitHelper:self didCompleteTransaction:transaction];
    }
}

@end
