#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreMotion/CoreMotion.h>

typedef struct {
    GLKVector2 pos;
    GLKVector2 vec;
    float radius;
} Object;

typedef struct {
    float x, y, z;
    float r, g, b, a;
} VertexData;

#define kOBJECT_MAX (512)
#define kGONS 8 // 多角形の角数
#define kVERTEX_COUNT (kGONS * 3)


@interface ViewController : GLKViewController {
    Object _objects[kOBJECT_MAX];
    VertexData _vertices[kOBJECT_MAX * kVERTEX_COUNT];
}

@end






