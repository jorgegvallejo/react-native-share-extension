#import "ReactNativeShareExtension.h"
#import "React/RCTRootView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <PassKit/PassKit.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText
#define PDF_IDENTIFIER (NSString *)kUTTypePDF
#define PASS_IDENTIFIER @"com.apple.pkpass"

NSExtensionContext* extensionContext;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    return nil;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
    [super viewDidLoad];

    //object variable for extension doesn't work for react-native. It must be assign to gloabl
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;

    UIView *rootView = [self shareView];
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }

    self.view = rootView;
}

RCT_EXPORT_METHOD(close) {
    [extensionContext completeRequestReturningItems:nil
                                  completionHandler:nil];
}

RCT_EXPORT_METHOD(openURL:(NSString *)url) {
  UIApplication *application = [UIApplication sharedApplication];
  NSURL *urlToOpen = [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  [application openURL:urlToOpen options:@{} completionHandler: nil];
}

RCT_REMAP_METHOD(data, resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject){
    [self extractDataFromContext: extensionContext withCallback:^(NSMutableArray* results, NSException* err) {
        if(err) {
            reject(@"error", err.description, nil);
        } else {
            resolve(results);
        }
    }];
}

- (NSString *)mimeTypeByGuessingFromData:(NSData *)data {

    char bytes[12] = {0};
    [data getBytes:&bytes length:12];

    const char bmp[2] = {'B', 'M'};
    const char gif[3] = {'G', 'I', 'F'};
    const char swf[3] = {'F', 'W', 'S'};
    const char swc[3] = {'C', 'W', 'S'};
    const char jpg[3] = {0xff, 0xd8, 0xff};
    const char psd[4] = {'8', 'B', 'P', 'S'};
    const char iff[4] = {'F', 'O', 'R', 'M'};
    const char webp[4] = {'R', 'I', 'F', 'F'};
    const char ico[4] = {0x00, 0x00, 0x01, 0x00};
    const char tif_ii[4] = {'I','I', 0x2A, 0x00};
    const char tif_mm[4] = {'M','M', 0x00, 0x2A};
    const char png[8] = {0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
    const char jp2[12] = {0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20, 0x0d, 0x0a, 0x87, 0x0a};


    if (!memcmp(bytes, bmp, 2)) {
        return @"image/x-ms-bmp";
    } else if (!memcmp(bytes, gif, 3)) {
        return @"image/gif";
    } else if (!memcmp(bytes, jpg, 3)) {
        return @"image/jpeg";
    } else if (!memcmp(bytes, psd, 4)) {
        return @"image/psd";
    } else if (!memcmp(bytes, iff, 4)) {
        return @"image/iff";
    } else if (!memcmp(bytes, webp, 4)) {
        return @"image/webp";
    } else if (!memcmp(bytes, ico, 4)) {
        return @"image/vnd.microsoft.icon";
    } else if (!memcmp(bytes, tif_ii, 4) || !memcmp(bytes, tif_mm, 4)) {
        return @"image/tiff";
    } else if (!memcmp(bytes, png, 8)) {
        return @"image/png";
    } else if (!memcmp(bytes, jp2, 12)) {
        return @"image/jp2";
    }

    return @"application/octet-stream"; // default type

}

- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSMutableArray *results, NSException *exception))callback {
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSArray *attachments = item.attachments;

        __block NSItemProvider *urlProvider = nil;
        __block NSItemProvider *imageProvider = nil;
        __block NSItemProvider *textProvider = nil;
        __block NSItemProvider *docProvider = nil;
        __block NSItemProvider *passProvider = nil;
        
        NSMutableArray *results = [NSMutableArray arrayWithCapacity:10];
        
        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {

            if([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]) {
                urlProvider = provider;
                [urlProvider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    
                    NSURL *url = (NSURL *)item;
                    NSMutableDictionary *result = [NSMutableDictionary dictionary];
                    
                    [result setObject:[url absoluteString] forKey:@"uri"];
                    [result setObject:@"text/plain" forKey:@"type"];
                    [results addObject:result];
                    
                    if(callback){
                        callback(results, nil);
                    }
                }];
                //*stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                textProvider = provider;
                [textProvider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    
                    NSString *text = (NSString *)item;
                    NSMutableDictionary *result = [NSMutableDictionary dictionary];
                    
                    [result setObject:text forKey: @"text"];
                    [result setObject:@"text/plain" forKey: @"type"];
                    [results addObject:result];

                    if([attachments count] == idx+1){
                        if(callback){
                            callback(results,nil);
                        }
                    }
                }];
                //*stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                imageProvider = provider;
                [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    
                    NSURL *url = (NSURL *)item;
                    NSMutableDictionary *result = [NSMutableDictionary dictionary];

                    if([url isKindOfClass:[NSURL class]]){
                        [result setObject:[url absoluteString] forKey: @"uri"];
                        [result setObject:[[[url absoluteString] pathExtension] lowercaseString] forKey: @"type"];
                    }
                    else{
                        NSData *imageData = UIImagePNGRepresentation(url);
                        NSString *base64String = [imageData base64EncodedStringWithOptions:0];
                        [result setObject:base64String forKey: @"base64"];
                        [result setObject:[self mimeTypeByGuessingFromData: imageData] forKey:@"type"];
                    }
                    [results addObject:result];
                    if([attachments count] == idx+1){
                        if(callback){
                            callback(results,nil);
                        }
                    }
                    
                }];
                //*stop = YES;
            }else if([provider hasItemConformingToTypeIdentifier:PDF_IDENTIFIER]){
                docProvider = provider;
                [docProvider loadItemForTypeIdentifier:PDF_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    
                    NSURL *url = (NSURL *)item;
                    NSMutableDictionary *result = [NSMutableDictionary dictionary];

                    [result setObject:[url absoluteString] forKey: @"uri"];
                    [result setObject:[[[url absoluteString] pathExtension] lowercaseString] forKey:@"type"];
                    [results addObject: result];

                    if([attachments count] == idx+1){
                        if(callback){
                            callback(results,nil);
                        }
                    }
                }];
            }else if([provider hasItemConformingToTypeIdentifier:PASS_IDENTIFIER]){
                passProvider = provider;
                [passProvider loadItemForTypeIdentifier:PASS_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                    
                    NSMutableDictionary *result = [NSMutableDictionary dictionary];

                    [result setObject:item forKey: @"item"];
                    [result setObject:@"application/vnd.apple.pkpass" forKey:@"type"];
                    [results addObject:result];

                    if([attachments count] == idx+1){
                        if(callback){
                            callback(results,nil);
                        }
                    }
                }];
            }else{
                callback(nil, [NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil]);
                *stop = YES;
            }
        }];
    }
    @catch (NSException *exception) {
        if(callback) {
            callback(nil, exception);
        }
    }
}

@end

