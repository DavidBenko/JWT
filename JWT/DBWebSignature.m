//
//  DBWebSignature.m
//  JWT
//
//  Created by David Benko on 2/13/15.
//  Copyright (c) 2015 Karma. All rights reserved.
//

#import "DBWebSignature.h"

#import "NSString+JWT.h"
#import "NSData+JWT.h"

#import "JWTAlgorithmHS512.h"
#import "JWTClaimsSetSerializer.h"

@interface DBWebSignature ()
@property (nonatomic, strong) NSString *secret;
@property (nonatomic, strong) id<JWTAlgorithm> algorithm;
@end

@implementation DBWebSignature

static NSString * const delimiter = @".";

#pragma mark - Init

- (instancetype)initWithSecret:(NSString *)secret algorithm:(id<JWTAlgorithm>)algorithm {
    
    NSParameterAssert(secret && algorithm);
    
    if (self = [super init]) {
        self.secret = secret;
        self.algorithm = algorithm;
        return self;
    }
    
    return nil;
}

#pragma mark - Token Generation

- (NSString *)encodeSegment:(id)theSegment {
    
    // Strings are not JSON
    if ([theSegment isKindOfClass:[NSString class]]) {
        return [theSegment base64UrlEncodedString];
    }
    
    
    NSError *error;
    NSString *encodedSegment = [[NSJSONSerialization dataWithJSONObject:theSegment options:0 error:&error] base64UrlEncodedString];
    
    NSAssert(!error, @"Could not encode segment: %@", [error localizedDescription]);
    return encodedSegment;
}

- (NSString *)generateToken:(id)payload{
    NSDictionary *header = @{@"typ": @"JWT", @"alg": self.algorithm.name};
    
    NSString *headerSegment = [self encodeSegment:header];
    NSString *payloadSegment = [self encodeSegment:payload];
    
    NSString *signingInput = [@[headerSegment, payloadSegment] componentsJoinedByString:delimiter];
    NSString *signedOutput = [[self.algorithm encodePayload:signingInput withSecret:self.secret] base64UrlEncodedString];
    return [@[headerSegment, payloadSegment, signedOutput] componentsJoinedByString:delimiter];
}

#pragma mark - Token Validation

- (BOOL) embeddedPayloadMatchesSignature:(NSString *)token{
    return [[self generateToken:[self embeddedPayloadAsString:token]] isEqualToString:token];
}

- (NSString *)embeddedPayloadAsString:(NSString *)token {
    NSArray *components = [token componentsSeparatedByString:delimiter];
    if (components.count != 3) {
        NSLog(@"Error: invalid token");
        return nil;
    }
    
    return [[components objectAtIndex:1] base64UrlDecodedString];
}

- (id) embeddedPayloadAsJSONObject:(NSString *)token {
    NSError *jsonError;
    NSData *payloadData = [[self embeddedPayloadAsString:token] dataUsingEncoding:NSUTF8StringEncoding];
    id json = [NSJSONSerialization JSONObjectWithData:payloadData
                                              options:0
                                                error:&jsonError];
    
    if (jsonError) {
        NSLog(@"JSON Error: %@", [jsonError localizedDescription]);
        return nil;
    }
    
    return json;
}


- (BOOL)validateToken:(NSString *)token payload:(id)payload{
    return [[self embeddedPayloadAsJSONObject:token] isEqual:payload] && [self embeddedPayloadMatchesSignature:token];
}

#pragma mark - Claim Set Encoding

- (NSString *)encodeClaimsSet:(JWTClaimsSet *)claimsSet {
    NSDictionary *payload = [JWTClaimsSetSerializer dictionaryWithClaimsSet:claimsSet];
    return [self generateToken:payload];
}

@end
