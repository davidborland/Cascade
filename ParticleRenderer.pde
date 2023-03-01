/*=========================================================================
 
 Name:        ParticleRenderer.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Class for rendering the particles of a fluid simulation.
 
=========================================================================*/


class ParticleRenderer {
  private float radius;
  private float opacity;
  private float densityThreshold;
  
  private PImage kernelImage;    
  private PShape kernel;
  
  private PGraphics renderBuffer;
  private PGraphics imageBuffer;
  
  private PShader densityShader;
  
  // XXX: Should be enums, but enums don't work in .pde files
  public static final int DRAW_PARTICLES = 0;
  public static final int DRAW_DENSITY = 1;
  private int drawMode;
  
  public static final int KERNEL_GAUSSIAN = 0;
  private int kernelType;
  
  private List<FluidSimulation.Particle> particles;
  
  
  ParticleRenderer() {
    radius = 0.09;
    opacity = 0.6;
    
    drawMode = DRAW_DENSITY;
    kernelType = KERNEL_GAUSSIAN;
   
    // Create the render buffer    
    renderBuffer = createGraphics(width, height, P3D);
    
    renderBuffer.beginDraw();
    
    renderBuffer.colorMode(RGB, 1.0);
    renderBuffer.smooth();      
    renderBuffer.imageMode(CENTER);    
    
    renderBuffer.scale(screen2pixels, screen2pixels);
    
    renderBuffer.endDraw();      
         
    // Create the kernel         
    CreateKernel();
    
    // Create the density shader
    densityShader = loadShader("particleDensity_fp.glsl");
    SetDensityThreshold(0.5);
  }
  
  public void SetParticles(List<FluidSimulation.Particle> particles) {
    this.particles = particles; 
  }
  
  public void SetRadius(float radius) {
    this.radius = radius;
    
    if (drawMode == DRAW_DENSITY) {
      CreateKernel(); 
    }
  }
  
  public float GetRadius() {
    return radius; 
  }
  
  public void SetOpacity(float opacity) {
    this.opacity = opacity;
    
    if (drawMode == DRAW_DENSITY) {
      CreateKernel(); 
    }
  }
  
  public float GetOpacity() {
    return opacity;
  }
  
  public void SetDensityThreshold(float densityThreshold) {
    this.densityThreshold = densityThreshold;
    densityShader.set("densityThreshold", densityThreshold);     
  }
  
  public float GetDensityThreshold() {
    return densityThreshold; 
  }
  
  public void SetDrawMode(int drawMode) {
    this.drawMode = drawMode;
   
    if (drawMode == DRAW_DENSITY) {
      CreateKernel(); 
    }
  }
  
  public int GetDrawMode() {
    return drawMode; 
  }
  
  public void Draw() {
    switch (drawMode) {
      
      case DRAW_PARTICLES:
        DrawParticles();
        break;
        
      case DRAW_DENSITY:
        DrawDensity();
        break;
    } 
  }
  
  public void CreateKernel() {
    switch (kernelType) {
      
      case KERNEL_GAUSSIAN:
        CreateGaussianKernel();
        break;
    }
  }
  
  private void DrawParticles() {
    pushMatrix();
    scale(screen2pixels);
    
    fill(0.5, 0.5, 1.0, opacity);
    noStroke();
    
    for (int i = 0; i < particles.size(); i++) {
      PVector pos = particles.get(i).pos;
      ellipse(pos.x, pos.y, radius * 2.0, radius * 2.0);      
    }
    
    popMatrix();
  }

  private void DrawDensity() { 
    // Splat kernels into renderBuffer
    renderBuffer.beginDraw();
  
    renderBuffer.background(0.0, 0.0, 0.0, 0.0);
    
    renderBuffer.scale(screen2pixels, screen2pixels);
    
    for (int i = 0; i < particles.size(); i++) {
        PVector pos = particles.get(i).pos;
        renderBuffer.pushMatrix();
        // XXX: For some reason this is getting flipped in y...
        renderBuffer.translate(pos.x, pos.y);
        
        renderBuffer.shape(kernel);        
        
        renderBuffer.popMatrix();
    }
      
    renderBuffer.endDraw();


    // Use a shader to render the density in the renderBuffer
    noStroke();
    noFill();
    
    shader(densityShader);

    beginShape(QUADS);
       
    texture(renderBuffer);
    vertex(    0, height, 0,     0, height);
    vertex(width, height, 0, width, height);
    vertex(width,      0, 0, width,      0);
    vertex(    0,      0, 0,     0,      0);
    
    endShape();
    
    resetShader();
  }

  private void CreateGaussianKernel() {    
    // Make the kernel width an odd number
    int w = (int)(radius * screen2pixels * 8);
    if (w % 2 == 0) {
      w++;
    }
    int c = w / 2;    
    float sigma = w / 8.0;
    
    kernelImage = new PImage(w, w);
    
    // Create mask image, as setting the alpha directly doesn't seem to work
    PImage mask = new PImage(w, w);
    
    // Generate the gaussian kernel
    float maxValue = 0.0;
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < w; y++) {    
        float v = exp(-(sq(x - c) + sq(y - c)) / (2 * sq(sigma)));
        
        mask.pixels[y * w + x] = color(v, v, v);
        kernelImage.pixels[y * w + x] = color(1.0, 1.0, 1.0);
        
        if (v > maxValue) maxValue = v;
      }
    }  
    
    // Scale the data range
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < w; y++) {
        float v = red(mask.pixels[y * w + x]);        
        v /= maxValue;
        v *= opacity;
        mask.pixels[y * w + x] = color(v, v, v);
      }
    }
    
    kernelImage.mask(mask);
  
    // Create the PShape to render the kernel
    float r = c * pixels2screen;
    
    kernel = renderBuffer.createShape();    
    kernel.beginShape(QUADS);    
    
    kernel.noStroke();
    kernel.texture(kernelImage);
    kernel.vertex(-r,  r, 0, 0, w);
    kernel.vertex( r,  r, 0, w, w);
    kernel.vertex( r, -r, 0, w, 0);
    kernel.vertex(-r, -r, 0, 0, 0);
    
    kernel.endShape();  
  } 
}  
