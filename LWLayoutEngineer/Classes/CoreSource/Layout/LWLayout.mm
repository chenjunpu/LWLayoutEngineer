//
//  LWLayout.m
//  LWLayoutEngineer
//
//  Created by sunshinelww on 2018/3/27.
//

#import "LWLayout.h"
#import "LWAssert.h"
#import <queue>
#import "LWLayoutUtilities.h"

CGPoint const LWPointNull = {NAN,NAN};

FOUNDATION_EXTERN BOOL LWPointIsNull(CGPoint point){
    return isnan(point.x) && isnan(point.y);
}

static inline BOOL LWLayoutIsViewType(LWLayout *layout) {
    return layout.layoutElementType == LWLayoutElementTypeView;
}

static inline BOOL LWLayoutIsFlattened(LWLayout *layout)
{
    if (!LWPointIsNull(layout.position)) {
        return NO;
    }
    
    for (LWLayout *sublayout in layout.subLayouts) {
        if (LWLayoutIsViewType(sublayout) == NO || sublayout.subLayouts.count > 0) {
            return NO;
        }
    }
    
    return YES;
}

@interface LWLayout()

@property (nonatomic, strong) NSMapTable *elementToRectMap;
@property (nonatomic, strong) NSMutableArray<id<LWLayoutable>> *subLayoutElements;

@end

@implementation LWLayout {
    LWLayoutElementType _layoutElementType;
}

- (instancetype)initWithLayoutElement:(id<LWLayoutable>)layoutElement
                                 size:(CGSize)size
                             position:(CGPoint)position
                       sublayoutElems:(NSArray<LWLayout *> *)sublayouts{
    self = [super init];
    if (self) {
        _layoutElement = layoutElement;
        //避免weak性能损失
        _layoutElementType = layoutElement.layoutElementType;
        _size = size;
        _position = position;
        _subLayouts = sublayouts != nil? [sublayouts copy] : @[];
        
        if (_subLayouts.count > 0) {
            _elementToRectMap = [NSMapTable strongToStrongObjectsMapTable];
            for (LWLayout *layout in sublayouts) {
                [_elementToRectMap setObject:[NSValue valueWithCGRect:layout.frame] forKey:layout.layoutElement];
            }
        }
    }
    return self;
}


+ (instancetype)layoutWithLayoutElement:(id<LWLayoutable>)layoutElement
                                   size:(CGSize)size
                               position:(CGPoint)position
                         sublayoutElems:(NSArray<LWLayout *> *)sublayouts {
    return [[self alloc] initWithLayoutElement:layoutElement size:size position:position sublayoutElems:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<LWLayoutable>)layoutElement
                                   size:(CGSize)size
                         sublayoutElems:(NSArray<LWLayout *> *)sublayouts {
    return [self layoutWithLayoutElement:layoutElement size:size position:LWPointNull sublayoutElems:sublayouts];
}

+ (instancetype)layoutWithLayoutElement:(id<LWLayoutable>)layoutElement size:(CGSize)size {
    return [self layoutWithLayoutElement:layoutElement size:size position:LWPointNull sublayoutElems:nil];
}

- (CGRect)frame {
    CGRect subnodeFrame = CGRectZero;
    CGPoint adjustedOrigin = _position;
    if (isfinite(adjustedOrigin.x) == NO) {
        LWLayoutEngineerAssert(0, @"Layout has an invalid position");
        adjustedOrigin.x = 0;
    }
    if (isfinite(adjustedOrigin.y) == NO) {
        LWLayoutEngineerAssert(0, @"Layout has an invalid position");
        adjustedOrigin.y = 0;
    }
    subnodeFrame.origin = adjustedOrigin;
    CGSize adjustedSize = _size;
    if (isfinite(adjustedSize.width) == NO) {
        LWLayoutEngineerAssert(0, @"Layout has an invalid size");
        adjustedSize.width = 0;
    }
    if (isfinite(adjustedSize.height) == NO) {
        LWLayoutEngineerAssert(0, @"Layout has an invalid position");
        adjustedSize.height = 0;
    }
    subnodeFrame.size = adjustedSize;
    
    return subnodeFrame;
}

- (CGRect)frameForElement:(id<LWLayoutable>)layoutElement {
    NSValue *value = self.elementToRectMap ? [self.elementToRectMap objectForKey:layoutElement] : nil;
    if (value == nil) {
        return CGRectNull;
    }
    return [value CGRectValue];
}

- (LWLayout *)filteredViewLayoutTree {
    struct LayoutContext {
        LWLayout *layout;
        CGPoint absolutePosition;
    };
    
    std::deque<LayoutContext> queue;
    for (LWLayout *subLayout in self.subLayouts) {
        queue.push_back({.layout = subLayout, .absolutePosition = subLayout.position});
    }
    NSMutableArray *flatternedSublayouts = [NSMutableArray array];
    while (!queue.empty()) {
        const LayoutContext context = queue.front();
        queue.pop_front();
        
        LWLayout *layout = context.layout;
        const NSArray<LWLayout *> *subLayouts = layout.subLayouts;
        const CGPoint absolutePosition = context.absolutePosition;
        
        if (LWLayoutIsViewType(layout)) { //如果是view
            if (subLayouts.count > 0) {
                layout = [LWLayout layoutWithLayoutElement:layout.layoutElement size:layout.size position:absolutePosition sublayoutElems:@[]];
            }
            [flatternedSublayouts addObject:layout];
        } else if (subLayouts.count > 0) { //是Specs
            std::vector<LayoutContext> subLayoutContexts;
            for (LWLayout *subLayout in subLayouts) {
                subLayoutContexts.push_back({.layout = subLayout, .absolutePosition = (absolutePosition + subLayout.position)});
            }
            queue.insert(queue.begin(), subLayoutContexts.begin(), subLayoutContexts.end());
        }
    }
    
    LWLayout *layout = [LWLayout layoutWithLayoutElement:_layoutElement size:_size sublayoutElems:flatternedSublayouts];
    [self retainSublayoutLayoutElements];
    return layout;
}

//强引用subLayouts的layouElement,由于Layout对layoutElement的引用是弱引用,避免在layoutSubSpecs中被创建的element被释放
- (void)retainSublayoutLayoutElements {
    NSUInteger subLayoutCount = self.subLayouts.count;
    if (subLayoutCount > 0) {
        self.subLayoutElements = [NSMutableArray array];
        for (LWLayout *subLayout in self.subLayouts) {
            [self.subLayoutElements addObject:subLayout.layoutElement];
        }
    }
}

- (LWLayoutElementType)layoutElementType {
    return _layoutElementType;
}

@end
