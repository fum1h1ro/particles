attribute vec4 position;
attribute vec4 color;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
//uniform mat3 normalMatrix;

void main()
{
    //colorVarying = color;
    colorVarying = vec4(1, 1, 1, 1);
    
    gl_Position = modelViewProjectionMatrix * position;
}
