//
//  JCStoreKitHelper.h
//  SubscriptionManager
//
//  Created by Joseph Chen on 12/17/13.
//  Copyright (c) 2013 Joseph Chen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class JCStoreKitHelper;

@protocol JCStoreKitHelperDelegate <NSObject>

- (void)storeKitHelper:(JCStoreKitHelper *)helper didCompleteTransaction:(SKPaymentTransaction *)transaction;

@end

@interface JCStoreKitHelper : NSObject <SKPaymentTransactionObserver>

@property (weak, nonatomic) id<JCStoreKitHelperDelegate> delegate;
@property (nonatomic, readonly) NSArray *products;

- (BOOL)requestProductData;
- (BOOL)buyProductWithIdentifier:(NSString *)productIdentifier
                      completion:(void (^)(BOOL, NSError *))completion;
- (BOOL)restorePreviousTransactionsWithCompletion:(void (^)(BOOL, NSError *))completion;

@end
