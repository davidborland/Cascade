#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
varying vec4 vertTexCoord;

uniform float densityThreshold;

void main() {
  vec4 color = texture2D(texture, vertTexCoord.st);
  
  if (color.r > densityThreshold) {
    color = vec4(0.2, 0.2, 0.75, pow(color.r, 0.5));
  }
  
  gl_FragColor = color;
}