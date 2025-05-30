//
//  FLEXUtility.m
//  Flipboard
//
//  由 Ryan Olson 创建于 4/18/14.
//  版权所有 (c) 2020 FLEX Team. 保留所有权利。
//

#import "FLEXColor.h"
#import "FLEXUtility.h"
#import "FLEXResources.h"
#import "FLEXWindow.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <zlib.h>

BOOL FLEXConstructorsShouldRun(void) {
    #if FLEX_DISABLE_CTORS
        return NO;
    #else
        static BOOL _FLEXConstructorsShouldRun_storage = YES;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *key = @"FLEX_SKIP_INIT";
            if (getenv(key.UTF8String) || [NSUserDefaults.standardUserDefaults boolForKey:key]) {
                _FLEXConstructorsShouldRun_storage = NO;
            }
        });
        
        return _FLEXConstructorsShouldRun_storage;
    #endif
}

@implementation FLEXUtility

+ (UIWindow *)appKeyWindow {
    // 首先，检查 UIApplication.keyWindow
    FLEXWindow *window = (id)UIApplication.sharedApplication.keyWindow;
    if (window) {
        if ([window isKindOfClass:[FLEXWindow class]]) {
            return window.previousKeyWindow;
        }
        
        return window;
    }
    
    // 从 iOS 13 开始，UIApplication.keyWindow 不会返回 nil，
    // 因此这更像是一个防止将来返回 nil 的安全保障。
    //
    // 此外，这些显然不全是 FLEXWindows；使用 FLEXWindow 
    // 是为了我们可以调用 window.previousKeyWindow 而不需要丑陋的类型转换
    for (FLEXWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) {
            if ([window isKindOfClass:[FLEXWindow class]]) {
                return window.previousKeyWindow;
            }
            
            return window;
        }
    }
    
    return nil;
}

+ (UIWindowScene *)activeScene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        // 寻找活跃的 UIWindowScene
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    
    return nil;
}

+ (UIViewController *)topViewControllerInWindow:(UIWindow *)window {
    UIViewController *topViewController = window.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}

+ (UIColor *)consistentRandomColorForObject:(id)object {
    CGFloat hue = (((NSUInteger)object >> 4) % 256) / 255.0;
    return [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:1.0];
}

+ (NSString *)descriptionForView:(UIView *)view includingFrame:(BOOL)includeFrame {
    NSString *description = [[view class] description];
    
    NSString *viewControllerDescription = [[[self viewControllerForView:view] class] description];
    if (viewControllerDescription.length > 0) {
        description = [description stringByAppendingFormat:@" (%@)", viewControllerDescription];
    }
    
    if (includeFrame) {
        description = [description stringByAppendingFormat:@" %@", [self stringForCGRect:view.frame]];
    }
    
    if (view.accessibilityLabel.length > 0 || view.accessibilityIdentifier.length > 0) {
        description = [description stringByAppendingFormat:@" · %@",
                       view.accessibilityLabel.length > 0 ? view.accessibilityLabel : view.accessibilityIdentifier];
    }
    
    return description;
}

+ (NSString *)stringForCGRect:(CGRect)rect {
    return [NSString stringWithFormat:@"{(%g, %g), (%g, %g)}",
        rect.origin.x, rect.origin.y, rect.size.width, rect.size.height
    ];
}

+ (UIViewController *)viewControllerForView:(UIView *)view {
    NSString *viewDelegate = @"_viewDelegate";
    if ([view respondsToSelector:NSSelectorFromString(viewDelegate)]) {
        return [view valueForKey:viewDelegate];
    }

    return nil;
}

+ (UIViewController *)viewControllerForAncestralView:(UIView *)view {
    NSString *_viewControllerForAncestor = @"_viewControllerForAncestor";
    if ([view respondsToSelector:NSSelectorFromString(_viewControllerForAncestor)]) {
        return [view valueForKey:_viewControllerForAncestor];
    }

    return nil;
}

+ (UIImage *)previewImageForView:(UIView *)view {
    if (CGRectIsEmpty(view.bounds)) {
        return [UIImage new];
    }
    
    CGSize viewSize = view.bounds.size;
    UIGraphicsBeginImageContextWithOptions(viewSize, NO, 0.0);
    [view drawViewHierarchyInRect:CGRectMake(0, 0, viewSize.width, viewSize.height) afterScreenUpdates:YES];
    UIImage *previewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return previewImage;
}

+ (UIImage *)previewImageForLayer:(CALayer *)layer {
    if (CGRectIsEmpty(layer.bounds)) {
        return nil;
    }
    
    UIGraphicsBeginImageContextWithOptions(layer.bounds.size, NO, 0.0);
    CGContextRef imageContext = UIGraphicsGetCurrentContext();
    [layer renderInContext:imageContext];
    UIImage *previewImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return previewImage;
}

+ (NSString *)detailDescriptionForView:(UIView *)view {
    return [NSString stringWithFormat:@"frame %@", [self stringForCGRect:view.frame]];
}

+ (UIImage *)circularImageWithColor:(UIColor *)color radius:(CGFloat)radius {
    CGFloat diameter = radius * 2.0;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), NO, 0.0);
    CGContextRef imageContext = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(imageContext, color.CGColor);
    CGContextFillEllipseInRect(imageContext, CGRectMake(0, 0, diameter, diameter));
    UIImage *circularImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return circularImage;
}

+ (UIColor *)hierarchyIndentPatternColor {
    static UIColor *patternColor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIImage *indentationPatternImage = FLEXResources.hierarchyIndentPattern;
        patternColor = [UIColor colorWithPatternImage:indentationPatternImage];
        if (@available(iOS 13.0, *)) {
            // 创建深色模式版本
            UIGraphicsBeginImageContextWithOptions(
                indentationPatternImage.size, NO, indentationPatternImage.scale
            );
            [FLEXColor.iconColor set];
            [indentationPatternImage drawInRect:CGRectMake(
                0, 0, indentationPatternImage.size.width, indentationPatternImage.size.height
            )];
            UIImage *darkModePatternImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            // 创建动态颜色提供者
            patternColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
                return (traitCollection.userInterfaceStyle == UIUserInterfaceStyleLight
                        ? [UIColor colorWithPatternImage:indentationPatternImage]
                        : [UIColor colorWithPatternImage:darkModePatternImage]);
            }];
        }
    });

    return patternColor;
}

+ (NSString *)applicationImageName {
    return NSBundle.mainBundle.executablePath;
}

+ (NSString *)applicationName {
    return FLEXUtility.applicationImageName.lastPathComponent;
}

+ (NSString *)pointerToString:(void *)ptr {
    return [NSString stringWithFormat:@"%p", ptr];
}

+ (NSString *)addressOfObject:(id)object {
    return [NSString stringWithFormat:@"%p", object];
}

+ (NSString *)stringByEscapingHTMLEntitiesInString:(NSString *)originalString {
    static NSDictionary<NSString *, NSString *> *escapingDictionary = nil;
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        escapingDictionary = @{ @" " : @"&nbsp;",
                                @">" : @"&gt;",
                                @"<" : @"&lt;",
                                @"&" : @"&amp;",
                                @"'" : @"&apos;",
                                @"\"" : @"&quot;",
                                @"«" : @"&laquo;",
                                @"»" : @"&raquo;"
                                };
        regex = [NSRegularExpression regularExpressionWithPattern:@"(&|>|<|'|\"|«|»)" options:0 error:NULL];
    });
    
    NSMutableString *mutableString = originalString.mutableCopy;
    
    NSArray<NSTextCheckingResult *> *matches = [regex
        matchesInString:mutableString options:0 range:NSMakeRange(0, mutableString.length)
    ];
    for (NSTextCheckingResult *result in matches.reverseObjectEnumerator) {
        NSString *foundString = [mutableString substringWithRange:result.range];
        NSString *replacementString = escapingDictionary[foundString];
        if (replacementString) {
            [mutableString replaceCharactersInRange:result.range withString:replacementString];
        }
    }
    
    return [mutableString copy];
}

+ (UIInterfaceOrientationMask)infoPlistSupportedInterfaceOrientationsMask {
    NSArray<NSString *> *supportedOrientations = NSBundle.mainBundle.infoDictionary[@"UISupportedInterfaceOrientations"];
    UIInterfaceOrientationMask supportedOrientationsMask = 0;
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationPortrait"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskPortrait;
    }
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationMaskLandscapeRight"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskLandscapeRight;
    }
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationMaskPortraitUpsideDown"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskPortraitUpsideDown;
    }
    if ([supportedOrientations containsObject:@"UIInterfaceOrientationLandscapeLeft"]) {
        supportedOrientationsMask |= UIInterfaceOrientationMaskLandscapeLeft;
    }
    return supportedOrientationsMask;
}

+ (UIImage *)thumbnailedImageWithMaxPixelDimension:(NSInteger)dimension fromImageData:(NSData *)data {
    UIImage *thumbnail = nil;
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, 0);
    if (imageSource) {
        NSDictionary<NSString *, id> *options = @{
            (__bridge id)kCGImageSourceCreateThumbnailWithTransform : @YES,
            (__bridge id)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
            (__bridge id)kCGImageSourceThumbnailMaxPixelSize : @(dimension)
        };

        CGImageRef scaledImageRef = CGImageSourceCreateThumbnailAtIndex(
            imageSource, 0, (__bridge CFDictionaryRef)options
        );
        if (scaledImageRef) {
            thumbnail = [UIImage imageWithCGImage:scaledImageRef];
            CFRelease(scaledImageRef);
        }
        CFRelease(imageSource);
    }
    return thumbnail;
}

+ (NSString *)stringFromRequestDuration:(NSTimeInterval)duration {
    NSString *string = @"0s";
    if (duration > 0.0) {
        if (duration < 1.0) {
            string = [NSString stringWithFormat:@"%dms", (int)(duration * 1000)];
        } else if (duration < 10.0) {
            string = [NSString stringWithFormat:@"%.2fs", duration];
        } else {
            string = [NSString stringWithFormat:@"%.1fs", duration];
        }
    }
    return string;
}

+ (NSString *)statusCodeStringFromURLResponse:(NSURLResponse *)response {
    NSString *httpResponseString = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *statusCodeDescription = nil;
        if (httpResponse.statusCode == 200) {
            // 优先使用 OK 而不是默认的 "no error"
            statusCodeDescription = @"OK";
        } else {
            statusCodeDescription = [NSHTTPURLResponse localizedStringForStatusCode:httpResponse.statusCode];
        }
        httpResponseString = [NSString stringWithFormat:@"%ld %@", (long)httpResponse.statusCode, statusCodeDescription];
    }
    return httpResponseString;
}

+ (BOOL)isErrorStatusCodeFromURLResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        return httpResponse.statusCode >= 400;
    }
    
    return NO;
}

+ (NSArray<NSURLQueryItem *> *)itemsFromQueryString:(NSString *)query {
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray new];

    // [a=1, b=2, c=3]
    NSArray<NSString *> *queryComponents = [query componentsSeparatedByString:@"&"];
    for (NSString *keyValueString in queryComponents) {
        // [a, 1]
        NSArray<NSString *> *components = [keyValueString componentsSeparatedByString:@"="];
        if (components.count == 2) {
            NSString *key = components.firstObject.stringByRemovingPercentEncoding;
            NSString *value = components.lastObject.stringByRemovingPercentEncoding;

            [items addObject:[NSURLQueryItem queryItemWithName:key value:value]];
        }
    }

    return items.copy;
}

+ (NSString *)prettyJSONStringFromData:(NSData *)data {
    NSString *prettyString = nil;
    
    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if ([NSJSONSerialization isValidJSONObject:jsonObject]) {
        // 感谢 RaziPour1993
        prettyString = [[NSString alloc]
            initWithData:[NSJSONSerialization
                dataWithJSONObject:jsonObject options:NSJSONWritingPrettyPrinted error:NULL
            ]
            encoding:NSUTF8StringEncoding
        ];
        // NSJSONSerialization 会转义正斜杠。
        // 我们希望得到美观的 json，所以遍历并取消转义这些斜杠。
        prettyString = [prettyString stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
    } else {
        prettyString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    
    return prettyString;
}

+ (BOOL)isValidJSONData:(NSData *)data {
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] ? YES : NO;
}

// 感谢以下链接对此方法的帮助
// https://www.cocoanetics.com/2012/02/decompressing-files-into-memory/
// https://github.com/nicklockwood/GZIP
+ (NSData *)inflatedDataFromCompressedData:(NSData *)compressedData {
    NSData *inflatedData = nil;
    NSUInteger compressedDataLength = compressedData.length;
    if (compressedDataLength > 0) {
        z_stream stream;
        stream.zalloc = Z_NULL;
        stream.zfree = Z_NULL;
        stream.avail_in = (uInt)compressedDataLength;
        stream.next_in = (void *)compressedData.bytes;
        stream.total_out = 0;
        stream.avail_out = 0;

        NSMutableData *mutableData = [NSMutableData dataWithLength:compressedDataLength * 1.5];
        if (inflateInit2(&stream, 15 + 32) == Z_OK) {
            int status = Z_OK;
            while (status == Z_OK) {
                if (stream.total_out >= mutableData.length) {
                    mutableData.length += compressedDataLength / 2;
                }
                stream.next_out = (uint8_t *)[mutableData mutableBytes] + stream.total_out;
                stream.avail_out = (uInt)(mutableData.length - stream.total_out);
                status = inflate(&stream, Z_SYNC_FLUSH);
            }
            if (inflateEnd(&stream) == Z_OK) {
                if (status == Z_STREAM_END) {
                    mutableData.length = stream.total_out;
                    inflatedData = [mutableData copy];
                }
            }
        }
    }
    return inflatedData;
}

+ (BOOL)hasCompressedContentEncoding:(NSURLRequest *)request {
    NSString *contentEncoding = [request valueForHTTPHeaderField:@"Content-Encoding"];
    return ([contentEncoding rangeOfString:@"deflate" options:NSCaseInsensitiveSearch].length > 0 || [contentEncoding rangeOfString:@"gzip" options:NSCaseInsensitiveSearch].length > 0);
}

+ (NSArray<UIWindow *> *)allWindows {
    BOOL includeInternalWindows = YES;
    BOOL onlyVisibleWindows = NO;

    // 混淆选择器 allWindowsIncludingInternalWindows:onlyVisibleWindows:
    NSArray<NSString *> *allWindowsComponents = @[
        @"al", @"lWindo", @"wsIncl", @"udingInt", @"ernalWin", @"dows:o", @"nlyVisi", @"bleWin", @"dows:"
    ];
    SEL allWindowsSelector = NSSelectorFromString([allWindowsComponents componentsJoinedByString:@""]);

    NSMethodSignature *methodSignature = [[UIWindow class] methodSignatureForSelector:allWindowsSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];

    invocation.target = [UIWindow class];
    invocation.selector = allWindowsSelector;
    [invocation setArgument:&includeInternalWindows atIndex:2];
    [invocation setArgument:&onlyVisibleWindows atIndex:3];
    [invocation invoke];

    __unsafe_unretained NSArray<UIWindow *> *windows = nil;
    [invocation getReturnValue:&windows];
    return windows;
}

+ (UIAlertController *)alert:(NSString *)title message:(NSString *)message {
    return [UIAlertController
        alertControllerWithTitle:title
        message:message
        preferredStyle:UIAlertControllerStyleAlert
    ];
}

+ (SEL)swizzledSelectorForSelector:(SEL)selector {
    return NSSelectorFromString([NSString stringWithFormat:
        @"_flex_swizzle_%x_%@", arc4random(), NSStringFromSelector(selector)
    ]);
}

+ (BOOL)instanceRespondsButDoesNotImplementSelector:(SEL)selector class:(Class)cls {
    if ([cls instancesRespondToSelector:selector]) {
        unsigned int numMethods = 0;
        Method *methods = class_copyMethodList(cls, &numMethods);
        
        BOOL implementsSelector = NO;
        for (int index = 0; index < numMethods; index++) {
            SEL methodSelector = method_getName(methods[index]);
            if (selector == methodSelector) {
                implementsSelector = YES;
                break;
            }
        }
        
        free(methods);
        
        if (!implementsSelector) {
            return YES;
        }
    }
    
    return NO;
}

+ (void)replaceImplementationOfKnownSelector:(SEL)originalSelector
                                     onClass:(Class)class
                                   withBlock:(id)block
                            swizzledSelector:(SEL)swizzledSelector {
    // 此方法仅用于交换已知存在于类上的方法。
    // 如果不是这种情况，则退出。
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    if (!originalMethod) {
        return;
    }
    
    IMP implementation = imp_implementationWithBlock(block);
    class_addMethod(class, swizzledSelector, implementation, method_getTypeEncoding(originalMethod));
    Method newMethod = class_getInstanceMethod(class, swizzledSelector);
    method_exchangeImplementations(originalMethod, newMethod);
}

+ (void)replaceImplementationOfSelector:(SEL)selector
                           withSelector:(SEL)swizzledSelector
                               forClass:(Class)cls
                  withMethodDescription:(struct objc_method_description)methodDescription
                    implementationBlock:(id)implementationBlock undefinedBlock:(id)undefinedBlock {
    if ([self instanceRespondsButDoesNotImplementSelector:selector class:cls]) {
        return;
    }
    
    IMP implementation = imp_implementationWithBlock((id)(
        [cls instancesRespondToSelector:selector] ? implementationBlock : undefinedBlock)
    );
    
    Method oldMethod = class_getInstanceMethod(cls, selector);
    const char *types = methodDescription.types;
    if (oldMethod) {
        if (!types) {
            types = method_getTypeEncoding(oldMethod);
        }

        class_addMethod(cls, swizzledSelector, implementation, types);
        Method newMethod = class_getInstanceMethod(cls, swizzledSelector);
        method_exchangeImplementations(oldMethod, newMethod);
    } else {
        if (!types) {
            // 有些协议方法描述没有填充 .types
            // 将返回类型设置为 void 并忽略参数
            types = "v@:";
        }
        class_addMethod(cls, selector, implementation, types);
    }
}

@end
