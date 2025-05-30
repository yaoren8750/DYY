//
//  FLEXPropertyAttributes.m
//  FLEX
//
//  派生自 MirrorKit.
//  Created by Tanner on 7/5/15.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

#import "FLEXPropertyAttributes.h"
#import "FLEXRuntimeUtility.h"
#import "NSString+ObjcRuntime.h"
#import "NSDictionary+ObjcRuntime.h"


#pragma mark FLEXPropertyAttributes

@interface FLEXPropertyAttributes ()

@property (nonatomic) NSString *backingIvar;
@property (nonatomic) NSString *typeEncoding;
@property (nonatomic) NSString *oldTypeEncoding;
@property (nonatomic) SEL customGetter;
@property (nonatomic) SEL customSetter;
@property (nonatomic) BOOL isReadOnly;
@property (nonatomic) BOOL isCopy;
@property (nonatomic) BOOL isRetained;
@property (nonatomic) BOOL isNonatomic;
@property (nonatomic) BOOL isDynamic;
@property (nonatomic) BOOL isWeak;
@property (nonatomic) BOOL isGarbageCollectable;

- (NSString *)buildFullDeclaration;

@end

@implementation FLEXPropertyAttributes
@synthesize list = _list;

#pragma mark 初始化器

+ (instancetype)attributesForProperty:(objc_property_t)property {
    return [self attributesFromDictionary:[NSDictionary attributesDictionaryForProperty:property]];
}

+ (instancetype)attributesFromDictionary:(NSDictionary *)attributes {
    return [[self alloc] initWithAttributesDictionary:attributes];
}

- (id)initWithAttributesDictionary:(NSDictionary *)attributes {
    NSParameterAssert(attributes);
    
    self = [super init];
    if (self) {
        _dictionary           = attributes;
        _string               = attributes.propertyAttributesString;
        _count                = attributes.count;
        _typeEncoding         = attributes[kFLEXPropertyAttributeKeyTypeEncoding];
        _backingIvar          = attributes[kFLEXPropertyAttributeKeyBackingIvarName];
        _oldTypeEncoding      = attributes[kFLEXPropertyAttributeKeyOldStyleTypeEncoding];
        _customGetterString   = attributes[kFLEXPropertyAttributeKeyCustomGetter];
        _customSetterString   = attributes[kFLEXPropertyAttributeKeyCustomSetter];
        _customGetter         = NSSelectorFromString(_customGetterString);
        _customSetter         = NSSelectorFromString(_customSetterString);
        _isReadOnly           = attributes[kFLEXPropertyAttributeKeyReadOnly] != nil;
        _isCopy               = attributes[kFLEXPropertyAttributeKeyCopy] != nil;
        _isRetained           = attributes[kFLEXPropertyAttributeKeyRetain] != nil;
        _isNonatomic          = attributes[kFLEXPropertyAttributeKeyNonAtomic] != nil;
        _isWeak               = attributes[kFLEXPropertyAttributeKeyWeak] != nil;
        _isGarbageCollectable = attributes[kFLEXPropertyAttributeKeyGarbageCollectable] != nil;

        _fullDeclaration = [self buildFullDeclaration];
    }
    
    return self;
}

#pragma mark 其他

- (NSString *)description {
    return [NSString
        stringWithFormat:@"<%@ \"%@\", ivar=%@, readonly=%d, nonatomic=%d, getter=%@, setter=%@>",
        NSStringFromClass(self.class),
        self.string,
        self.backingIvar ?: @"无",
        self.isReadOnly,
        self.isNonatomic,
        NSStringFromSelector(self.customGetter) ?: @"无",
        NSStringFromSelector(self.customSetter) ?: @"无"
    ];
}

- (objc_property_attribute_t *)copyAttributesList:(unsigned int *)attributesCount {
    NSDictionary *attrs = self.string.propertyAttributes;
    objc_property_attribute_t *propertyAttributes = malloc(attrs.count * sizeof(objc_property_attribute_t));

    if (attributesCount) {
        *attributesCount = (unsigned int)attrs.count;
    }
    
    NSUInteger i = 0;
    for (NSString *key in attrs.allKeys) {
        FLEXPropertyAttribute c = (FLEXPropertyAttribute)[key characterAtIndex:0];
        switch (c) {
            case FLEXPropertyAttributeTypeEncoding: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyTypeEncoding.UTF8String,
                    self.typeEncoding.UTF8String
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeBackingIvarName: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyBackingIvarName.UTF8String,
                    self.backingIvar.UTF8String
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeCopy: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyCopy.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeCustomGetter: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyCustomGetter.UTF8String,
                    NSStringFromSelector(self.customGetter).UTF8String ?: ""
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeCustomSetter: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyCustomSetter.UTF8String,
                    NSStringFromSelector(self.customSetter).UTF8String ?: ""
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeDynamic: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyDynamic.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeGarbageCollectible: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyGarbageCollectable.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeNonAtomic: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyNonAtomic.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeOldTypeEncoding: {
                objc_property_attribute_t pa = {
                    kFLEXPropertyAttributeKeyOldStyleTypeEncoding.UTF8String,
                    self.oldTypeEncoding.UTF8String ?: ""
                };
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeReadOnly: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyReadOnly.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeRetain: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyRetain.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
            case FLEXPropertyAttributeWeak: {
                objc_property_attribute_t pa = {kFLEXPropertyAttributeKeyWeak.UTF8String, ""};
                propertyAttributes[i] = pa;
                break;
            }
        }
        i++;
    }
    
    return propertyAttributes;
}

- (objc_property_attribute_t *)list {
    if (!_list) {
        _list = [self copyAttributesList:nil];
    }

    return _list;
}

- (NSString *)buildFullDeclaration {
    NSMutableString *decl = [NSMutableString new];

    [decl appendFormat:@"%@, ", _isNonatomic ? @"nonatomic" : @"atomic"];
    [decl appendFormat:@"%@, ", _isReadOnly ? @"readonly" : @"readwrite"];

    BOOL noExplicitMemorySemantics = YES;
    if (_isCopy) { noExplicitMemorySemantics = NO;
        [decl appendString:@"copy, "];
    }
    if (_isRetained) { noExplicitMemorySemantics = NO;
        [decl appendString:@"strong, "];
    }
    if (_isWeak) { noExplicitMemorySemantics = NO;
        [decl appendString:@"weak, "];
    }

    if ([_typeEncoding hasPrefix:@"@"] && noExplicitMemorySemantics) {
        // *可能* 如果这是一个对象，则为strong；strong是默认值。
        [decl appendString:@"strong, "];
    } else if (noExplicitMemorySemantics) {
        // *可能* 如果这不是一个对象，则为assign
        [decl appendString:@"assign, "];
    }

    if (_customGetter) {
        [decl appendFormat:@"getter=%@, ", NSStringFromSelector(_customGetter)];
    }
    if (_customSetter) {
        [decl appendFormat:@"setter=%@, ", NSStringFromSelector(_customSetter)];
    }

    [decl deleteCharactersInRange:NSMakeRange(decl.length-2, 2)];
    return decl.copy;
}

- (void)dealloc {
    if (_list) {
        free(_list);
        _list = nil;
    }
}

#pragma mark 复制

- (id)copyWithZone:(NSZone *)zone {
    return [[FLEXPropertyAttributes class] attributesFromDictionary:self.dictionary];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return [[FLEXMutablePropertyAttributes class] attributesFromDictionary:self.dictionary];
}

@end



#pragma mark FLEXMutablePropertyAttributes

@interface FLEXMutablePropertyAttributes ()
@property (nonatomic) BOOL countDelta;
@property (nonatomic) BOOL stringDelta;
@property (nonatomic) BOOL dictDelta;
@property (nonatomic) BOOL listDelta;
@property (nonatomic) BOOL declDelta;
@end

#define PropertyWithDeltaFlag(type, name, Name) @dynamic name; \
- (void)set ## Name:(type)name { \
    if (name != _ ## name) { \
        _countDelta = _stringDelta = _dictDelta = _listDelta = _declDelta = YES; \
        _ ## name = name; \
    } \
}

@implementation FLEXMutablePropertyAttributes

PropertyWithDeltaFlag(NSString *, backingIvar, BackingIvar);
PropertyWithDeltaFlag(NSString *, typeEncoding, TypeEncoding);
PropertyWithDeltaFlag(NSString *, oldTypeEncoding, OldTypeEncoding);
PropertyWithDeltaFlag(SEL, customGetter, CustomGetter);
PropertyWithDeltaFlag(SEL, customSetter, CustomSetter);
PropertyWithDeltaFlag(BOOL, isReadOnly, IsReadOnly);
PropertyWithDeltaFlag(BOOL, isCopy, IsCopy);
PropertyWithDeltaFlag(BOOL, isRetained, IsRetained);
PropertyWithDeltaFlag(BOOL, isNonatomic, IsNonatomic);
PropertyWithDeltaFlag(BOOL, isDynamic, IsDynamic);
PropertyWithDeltaFlag(BOOL, isWeak, IsWeak);
PropertyWithDeltaFlag(BOOL, isGarbageCollectable, IsGarbageCollectable);

+ (instancetype)attributes {
    return [self new];
}

- (void)setTypeEncodingChar:(char)type {
    self.typeEncoding = [NSString stringWithFormat:@"%c", type];
}

- (NSUInteger)count {
    // 变更后重新计算属性数量
    if (self.countDelta) {
        self.countDelta = NO;
        _count = self.dictionary.count;
    }

    return _count;
}

- (objc_property_attribute_t *)list {
    // 变更后重新生成列表
    if (self.listDelta) {
        self.listDelta = NO;
        if (_list) {
            free(_list);
            _list = nil;
        }
    }

    // 如果未设置，父类将生成列表
    return super.list;
}

- (NSString *)string {
    // 变更后重新生成字符串
    if (self.stringDelta || !_string) {
        self.stringDelta = NO;
        _string = self.dictionary.propertyAttributesString;
    }

    return _string;
}

- (NSDictionary *)dictionary {
    // 变更后重新生成字典
    if (self.dictDelta || !_dictionary) {
        // _string 和 _dictionary 相互依赖，
        // 所以我们必须使用我们的属性手动生成其中一个。
        // 我们任意选择生成字典。
        NSMutableDictionary *attrs = [NSMutableDictionary new];
        if (self.typeEncoding)
            attrs[kFLEXPropertyAttributeKeyTypeEncoding]         = self.typeEncoding;
        if (self.backingIvar)
            attrs[kFLEXPropertyAttributeKeyBackingIvarName]      = self.backingIvar;
        if (self.oldTypeEncoding)
            attrs[kFLEXPropertyAttributeKeyOldStyleTypeEncoding] = self.oldTypeEncoding;
        if (self.customGetter)
            attrs[kFLEXPropertyAttributeKeyCustomGetter]         = NSStringFromSelector(self.customGetter);
        if (self.customSetter)
            attrs[kFLEXPropertyAttributeKeyCustomSetter]         = NSStringFromSelector(self.customSetter);

        if (self.isReadOnly)           attrs[kFLEXPropertyAttributeKeyReadOnly] = @YES;
        if (self.isCopy)               attrs[kFLEXPropertyAttributeKeyCopy] = @YES;
        if (self.isRetained)           attrs[kFLEXPropertyAttributeKeyRetain] = @YES;
        if (self.isNonatomic)          attrs[kFLEXPropertyAttributeKeyNonAtomic] = @YES;
        if (self.isDynamic)            attrs[kFLEXPropertyAttributeKeyDynamic] = @YES;
        if (self.isWeak)               attrs[kFLEXPropertyAttributeKeyWeak] = @YES;
        if (self.isGarbageCollectable) attrs[kFLEXPropertyAttributeKeyGarbageCollectable] = @YES;

        _dictionary = attrs.copy;
    }

    return _dictionary;
}

- (NSString *)fullDeclaration {
    if (self.declDelta || !_fullDeclaration) {
        _declDelta = NO;
        _fullDeclaration = [self buildFullDeclaration];
    }

    return _fullDeclaration;
}

- (NSString *)customGetterString {
    return _customGetter ? NSStringFromSelector(_customGetter) : nil;
}

- (NSString *)customSetterString {
    return _customSetter ? NSStringFromSelector(_customSetter) : nil;
}

@end
