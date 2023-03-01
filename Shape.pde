/*=========================================================================
 
 Name:        Shape.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Classes for rendering various 2D shapes, including images
              loaded from files.
 
=========================================================================*/


abstract class Shape {
  protected PVector pos;
  protected PVector bb;
  
  protected float opacity;
  
  Shape(float posX, float posY, float bbWidth, float bbHeight) {
    pos = new PVector(posX, posY);
    bb = new PVector(bbWidth, bbHeight);
    
    opacity = 1.0;
  }
  
  Shape(PVector _pos, PVector _bb) {
    this(_pos.x, _pos.y, _bb.x, _bb.y);
  }
 
  abstract public void Draw(PGraphics pg);
  abstract public void DrawOutline(PGraphics pg);
   
  abstract public boolean IsInside(float x, float y); 
   
  public boolean IsInside(PVector p) {
    return IsInside(p.x, p.y);
  }
 
  public void Translate(PVector v) {
    pos.add(v);
  } 
}


class Ellipse extends Shape {
  Ellipse(float posX, float posY, float bbWidth, float bbHeight) {
    super(posX, posY, bbWidth, bbHeight);
  }
  
  Ellipse(PVector pos, PVector bb) {
    super(pos, bb);
  }
  
  public void Draw(PGraphics pg) {
    pg.fill(0.0, 0.0, 0.0, opacity);
    pg.noStroke();

    pg.ellipseMode(CENTER);
    pg.ellipse(pos.x, pos.y, bb.x, bb.y);
  }
  
  public void DrawOutline(PGraphics pg) {
    pg.noFill();
    pg.stroke(0.0, 0.0, 0.0, opacity);
    pg.strokeWeight(1);

    pg.ellipseMode(CENTER);
    pg.ellipse(pos.x, pos.y, bb.x, bb.y);
  }
  
  public boolean IsInside(float x, float y) {
    x -= pos.x;
    y -= pos.y;
    
    float rx = bb.x * 0.5;
    float ry = bb.y * 0.5;
    
    float v = (x * x) / (rx * rx) + (y * y) / (ry * ry);
   
    return v <= 1.0;
  }
}


class Rectangle extends Shape {
  Rectangle(float posX, float posY, float bbWidth, float bbHeight) {
    super(posX, posY, bbWidth, bbHeight);
  }
  
  Rectangle(PVector pos, PVector bb) {
    super(pos, bb);
  }
  
  public void Draw(PGraphics pg) {
    pg.fill(0.0, 0.0, 0.0, opacity);
    pg.noStroke();
     
    pg.rectMode(CENTER);
    pg.rect(pos.x, pos.y, bb.x, bb.y); 
  }
  
  public void DrawOutline(PGraphics pg) {
    pg.noFill();
    pg.stroke(0.0, 0.0, 0.0, opacity);
    pg.strokeWeight(1);
       
    pg.rectMode(CENTER);
    pg.rect(pos.x, pos.y, bb.x, bb.y);
  }
  
  public boolean IsInside(float x, float y) {    
    float w = bb.x / 2.0;
    float h = bb.y / 2.0;
    
    return x >= pos.x - w &&
           x <= pos.x + w &&
           y >= pos.y - h &&
           y <= pos.y + h; 
  }
}


class Trapezoid extends Shape {
  private float yScale;
  
  Trapezoid(float posX, float posY, float bbWidth, float bbHeight, float yScale) {
    super(posX, posY, bbWidth, bbHeight);
    
    this.yScale = yScale;
  }
  
  Trapezoid(PVector pos, PVector bb, float yScale) {
    super(pos, bb);
    
    this.yScale = yScale;
  }
  
  
  public void Draw(PGraphics pg) {
    pg.fill(0.0, 0.0, 0.0, opacity);
    pg.noStroke();

    pg.quad(pos.x - bb.x * 0.5, pos.y + bb.y * 1.0,
            pos.x + bb.x * 0.5, pos.y + bb.y * yScale,
            pos.x + bb.x * 0.5, pos.y - bb.y * yScale,
            pos.x - bb.x * 0.5, pos.y - bb.y * 1.0);
  }
  
  public void DrawOutline(PGraphics pg) {
    pg.noFill();
    pg.stroke(0.0, 0.0, 0.0, opacity);
    pg.strokeWeight(1);
       
    pg.quad(pos.x - bb.x * 0.5, pos.y + bb.y * 1.0,
            pos.x + bb.x * 0.5, pos.y + bb.y * yScale,
            pos.x + bb.x * 0.5, pos.y - bb.y * yScale,
            pos.x - bb.x * 0.5, pos.y - bb.y * 1.0);
  }
  
  public boolean IsInside(float x, float y) {   
    float w = bb.x / 2.0;
    float h = bb.y / 2.0;
    
    return x >= pos.x - w &&
           x <= pos.x + w &&
           y >= pos.y - h &&
           y <= pos.y + h; 
  }
}

class Wedge extends Shape { 
  private float yScale;
  
  Wedge(float posX, float posY, float bbWidth, float bbHeight) {
    super(posX, posY, bbWidth, bbHeight);
  }
  
  Wedge(PVector pos, PVector bb) {
    super(pos, bb);
  }
  
  
  public void Draw(PGraphics pg) {
    pg.fill(0.0, 0.0, 0.0, opacity);
    pg.noStroke();

    pg.triangle(pos.x - bb.x * 0.5, pos.y + bb.y * 0.5,
                pos.x + bb.x * 0.5, pos.y + bb.y * 0.5,
                pos.x - bb.x * 0.5, pos.y - bb.y * 0.5);
  }
  
  public void DrawOutline(PGraphics pg) {
    pg.noFill();
    pg.stroke(0.0, 0.0, 0.0, opacity);
    pg.strokeWeight(1);

    pg.triangle(pos.x - bb.x * 0.5, pos.y + bb.y * 0.5,
                pos.x + bb.x * 0.5, pos.y + bb.y * 0.5,
                pos.x - bb.x * 0.5, pos.y - bb.y * 0.5);
  }
  
  public boolean IsInside(float x, float y) {
    // Only using this for a static image, so don't worry about implementing for now   
    return false;
  }
}


class Image extends Shape {
  private PImage image;
  
  private static final float threshold = 0.8;
  
  
  Image(float posX, float posY, PImage image) {    
    super(posX, posY, image.width, image.height);        
    
    pos.x *= screen2pixels;
    pos.y *= screen2pixels;
    
    // XXX: This is repeatedly filtering the same image, but that is okay for now.
    image.filter(GRAY);
    
    // Find bounding box
    int xMin = image.width - 1;
    int xMax = 0;
    int yMin = image.height - 1;
    int yMax = 0;
    for (int x = 0; x < image.width; x++ ) {
      for (int y = 0; y < image.height; y++) {
        color c = image.get(x, y);
        if (red(c) <= threshold) {
          if (x < xMin) xMin = x;
          if (x > xMax) xMax = x;
          if (y < yMin) yMin = y;
          if (y > yMax) yMax = y;
        }
      }
    }
    
    int w = xMax - xMin + 1;
    int h = yMax - yMin + 1;
    
    // Copy image cropped by bounding box
    this.image = new PImage(w, h);
    this.image.copy(image, xMin, yMin, w, h, 0, 0, w, h);
    this.image.filter(GRAY);
    
    // Apply opacity mask
    PImage mask = new PImage(w, h);
    mask.copy(this.image, 0, 0, w, h, 0, 0, w, h);
    mask.filter(THRESHOLD, threshold);
    mask.filter(INVERT);
    
    this.image.mask(mask);
    
    // Update bounding box
    bb.x = this.image.width;
    bb.y = this.image.height;
  }
  
  Image(PVector pos, PImage image) {   
    this(pos.x, pos.y, image); 
  }
  

  public void Draw(PGraphics pg) {
    // Scaling the image doesn't seem to work, so pop the matrix and render at full resolution.    
    pg.pushMatrix();
    pg.resetMatrix();
    
    pg.imageMode(CENTER);
    
    pg.image(image, pos.x, pos.y);

    pg.popMatrix();
  }
  
  public void DrawOutline(PGraphics pg) {
    pg.noFill();
    pg.stroke(0.0, 0.0, 0.0, opacity);
    pg.strokeWeight(1);
       
    pg.rectMode(CENTER);
    pg.rect(pos.x, pos.y, bb.x, bb.y);
  }
  
  public boolean IsInside(float x, float y) {   
    int[] p = Screen2Pixels(x, y);
    x = p[0];
    y = p[1];
    
    float w = bb.x / 2.0;
    float h = bb.y / 2.0;
    
    int ix = (int)(x - (pos.x - w));
    int iy = (int)(y - (pos.y - h));
    
    return x >= pos.x - w &&
           x <= pos.x + w &&
           y >= pos.y - h &&
           y <= pos.y + h &&
           brightness(image.get(ix, iy)) < threshold; 
  }
  
  public void Translate(PVector v) {
    pos.x += v.x * screen2pixels;
    pos.y += v.y * screen2pixels;
  } 
}
