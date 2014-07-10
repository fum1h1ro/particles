#import "ViewController.h"

// Uniform index.
enum {
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];


@interface ViewController () {
    GLuint _program;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    GLKVector2 _acceleration;
    float _rotation;
    float _width, _height;
    float _left, _right, _top, _bottom;
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    CMMotionManager* _motionManager;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ViewController

// =================================================================
// 
- (void)setupObjects {
    _acceleration = GLKVector2Make(0, 0);
    for (int i = 0; i < kOBJECT_MAX; ++i) {
        _objects[i].pos = GLKVector2Make(rand() % 10, rand() % 10);
        _objects[i].vec = GLKVector2Make(0, 0);
        _objects[i].radius = 3;
    }
}
//
- (void)updateObjects:(float)dt {
    CMAccelerometerData* acc = _motionManager.accelerometerData;
    _acceleration.x = acc.acceleration.x * 100.0f;
    _acceleration.y = acc.acceleration.y * 100.0f;
    for (int i = 0; i < kOBJECT_MAX; ++i) {
        Object* objA = &_objects[i];
        objA->vec = GLKVector2Add(objA->vec, GLKVector2MultiplyScalar(_acceleration, dt));
        objA->pos = GLKVector2Add(objA->pos, GLKVector2MultiplyScalar(objA->vec, dt));
        const float radius = objA->radius;
        if (objA->pos.x < _left + radius) {
            objA->pos.x += (_left + radius) - objA->pos.x;
            objA->vec.x = 0.0f;
        }
        if (_right - radius < objA->pos.x) {
            objA->pos.x -= objA->pos.x - (_right - radius);
            objA->vec.x = 0.0f;
        }
        if (objA->pos.y < _bottom + radius) {
            objA->pos.y += (_bottom + radius) - objA->pos.y;
            objA->vec.y = 0.0f;
        }
        if (_top - radius < objA->pos.y) {
            objA->pos.y -= objA->pos.y - (_top - radius);
            objA->vec.y = 0.0f;
        }
        for (int j = 0; j < kOBJECT_MAX; ++j) {
            if (i == j) continue; // 自分とは当たりを取らない
            Object* objB = &_objects[j];
            GLKVector2 d = GLKVector2Subtract(objA->pos, objB->pos);
            float dist = GLKVector2Length(d);
            float minlen = objA->radius + objB->radius;
            if (dist < minlen) {
                d = GLKVector2Normalize(d);
                float h = (minlen - dist) * 0.5f;
                objA->pos = GLKVector2Add(objA->pos, GLKVector2MultiplyScalar(d, +h));
                objB->pos = GLKVector2Add(objB->pos, GLKVector2MultiplyScalar(d, -h));
            }
        }
    }
}
- (void)renderObjects {
    for (int i = 0; i < kOBJECT_MAX; ++i) {
        Object* objA = &_objects[i];

        int top = kVERTEX_COUNT * i;

        for (int j = 0; j < kGONS; ++j) {
            VertexData* v0 = &_vertices[top + j * 3 + 0];
            VertexData* v1 = &_vertices[top + j * 3 + 1];
            VertexData* v2 = &_vertices[top + j * 3 + 2];

            v0->x = objA->pos.x;
            v0->y = objA->pos.y;
            v0->z = -10.0f;
            v1->x = v0->x + cos((2.0 * M_PI / (double)kGONS) * (j+0)) * objA->radius;
            v1->y = v0->y + sin((2.0 * M_PI / (double)kGONS) * (j+0)) * objA->radius;
            v1->z = -10.0f;
            v2->x = v0->x + cos((2.0 * M_PI / (double)kGONS) * (j+1)) * objA->radius;
            v2->y = v0->y + sin((2.0 * M_PI / (double)kGONS) * (j+1)) * objA->radius;
            v2->z = -10.0f;

            v0->r = v0->g = v0->b = v0->a = 1.0f;
            v1->r = v1->g = v1->b = v1->a = 1.0f;
            v2->r = v2->g = v2->b = v2->a = 1.0f;
        }
    }
    //glBindVertexArrayOES(_vertexArray);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(_vertices), _vertices, GL_DYNAMIC_DRAW);
}

// =================================================================


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    self.preferredFramesPerSecond = 60;
    [self initialize];
}

- (void)dealloc
{    
    [self finalize];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

- (void)initialize {
    [self setupGL];
    [self setupObjects];
    _width = self.view.bounds.size.width;
    _height = self.view.bounds.size.height;
    _left = -_width * 0.5f;
    _right = _left + _width;
    _bottom = -_height * 0.5f;
    _top = _bottom + _height;

    _motionManager = [[CMMotionManager alloc] init];
    if (_motionManager.accelerometerAvailable) {
        _motionManager.accelerometerUpdateInterval = 1.0/100.0;
        _motionManager.startAccelerometerUpdates;
    }


}

- (void)finalize {
    [self tearDownGL];
}

- (void)setupGL {
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    //glBufferData(GL_ARRAY_BUFFER, sizeof(gCubeVertexData), gCubeVertexData, GL_STATIC_DRAW);
    glBufferData(GL_ARRAY_BUFFER, sizeof(_vertices), _vertices, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(VertexData), offsetof(VertexData, x));
    glEnableVertexAttribArray(GLKVertexAttribColor);
    glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, sizeof(VertexData), offsetof(VertexData, r));
    
    glBindVertexArrayOES(0);
}

- (void)tearDownGL {
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    self.effect = nil;
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}


#pragma mark - GLKView and GLKViewController delegate methods

- (void)update {
    float w = self.view.bounds.size.width;
    float hw = w * 0.5f;
    float h = self.view.bounds.size.height;
    float hh = h * 0.5f;
    //float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    //GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(-hw, +hw, -hh, +hh, 0.1f, 100.0f);
    
    self.effect.transform.projectionMatrix = projectionMatrix;
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -4.0f);
    baseModelViewMatrix = GLKMatrix4Rotate(baseModelViewMatrix, _rotation, 0.0f, 1.0f, 0.0f);
    
    // Compute the model view matrix for the object rendered with GLKit
    GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    self.effect.transform.modelviewMatrix = modelViewMatrix;
    
    // Compute the model view matrix for the object rendered with ES2
    modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    
    //_modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    _modelViewProjectionMatrix = projectionMatrix;
    
    _rotation += self.timeSinceLastUpdate * 0.5f;
    [self updateObjects:self.timeSinceLastUpdate];
}

- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect {
    glClearColor(0.65f, 0.65f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    [self renderObjects];
    glBindVertexArrayOES(_vertexArray);
    // Render the object again with ES2
    glUseProgram(_program);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glDrawArrays(GL_TRIANGLES, 0, kOBJECT_MAX * kVERTEX_COUNT);
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribColor, "color");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    //uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
