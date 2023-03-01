/*=========================================================================
 
 Name:        Homography.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Processing sketch to test performing a homography from the 
              projection of a rectangle to a rectangle.
 
=========================================================================*/


import javax.media.jai.*;


// The input image
PImage img;

// Upper-left, lower-left, lower-right, and upper-right control points
PVector[] p1;
PVector[] p2;

// Currently selected point
PVector currentP = null;
PVector oldMouse;

// Point radius
float radius = 20;

// Transformation matrix
PerspectiveTransform mat = new PerspectiveTransform();

//float[] points1;
//float[] points2;

//int tSize;


void setup() {
  size(1800, 600);
  
  colorMode(RGB, 1.0);
  
  smooth();
  
  img = loadImage("ben.jpg");
  img.resize(width / 2, height);
/*   
  tSize = width / 2 * height * 2;
  points1 = new float[tSize];
  points2 = new float[tSize];
  for (int x = 0; x < width / 2; x++) {
    for (int y = 0; y < height; y++) {
       points[y * width / 2 + x] = x;
       points[y * width / 2 + x + 1] = y;
    }
  }
  for (int i = 0; i < points1.length; i += 2) {
    points2[i] = 
  }
*/  
  p1 = new PVector[4];
  p1[0] = new PVector(img.width * 1.0 / 3.0, img.height * 1.0 / 3.0); 
  p1[1] = new PVector(img.width * 1.0 / 3.0, img.height * 2.0 / 3.0);
  p1[2] = new PVector(img.width * 2.0 / 3.0, img.height * 2.0 / 3.0);
  p1[3] = new PVector(img.width * 2.0 / 3.0, img.height * 1.0 / 3.0);
  
  p2 = new PVector[4];
  p2[0] = new PVector(0,         0); 
  p2[1] = new PVector(0,         img.height);
  p2[2] = new PVector(img.width, img.height);
  p2[3] = new PVector(img.width, 0);
  
  computeMatrix(p2, p1);
  
  oldMouse = new PVector();
}


void draw() {
  background(0.0, 0.0, 0.0, 0.0);
 
 
  // Draw the original image
  image(img, 0, 0, img.width, img.height); 
  
  
  // Draw the control points
  strokeWeight(1);
  fill(1.0, 1.0, 1.0, 0.5);
  
  beginShape(QUADS);
  
  vertex(p1[0].x, p1[0].y);
  vertex(p1[1].x, p1[1].y);
  vertex(p1[2].x, p1[2].y);
  vertex(p1[3].x, p1[3].y);
  
  endShape();
      
  for (int i = 0; i < p1.length; i++) {    
    strokeWeight(2);
    stroke(0.0, 0.0, 0.0, 0.5);
    noFill();
    ellipse(p1[i].x, p1[i].y, radius, radius);
  } 
  
  
  // Draw the transformed image
  float[] p1 = new float[2];
  float[] p2 = new float[2];
  for (int x = 0; x < img.width; x++) {
    for (int y = 0; y < img.height; y++) {
      p2[0] = x;
      p2[1] = y;
      mat.transform(p2, 0, p1, 0, 1);
      
      set(x + width / 2, y, img.get((int)p1[0], (int)p1[1]));
    } 
  }
}

void mousePressed() {
  PVector m = new PVector(mouseX, mouseY);
  
  // Pick control points
  for (int i = 0; i < p1.length; i++) {
    if (PVector.dist(m, p1[i]) <= radius) {
      currentP = p1[i];
      break;
    } 
  }
  
  oldMouse = m;
}

void mouseReleased() {
  currentP = null; 
}

void mouseDragged() {
  if (currentP == null) return;
  
  PVector m = new PVector(mouseX, mouseY);  
  PVector v = PVector.sub(m, oldMouse);
  
  currentP.add(v);
  
  oldMouse = m.get();
    
  computeMatrix(p2, p1);
}

void computeMatrix(PVector[] p1, PVector[] p2) {
  mat = PerspectiveTransform.getQuadToQuad(p1[0].x, p1[0].y, 
                                           p1[1].x, p1[1].y, 
                                           p1[2].x, p1[2].y, 
                                           p1[3].x, p1[3].y,
                    
                                           p2[0].x, p2[0].y, 
                                           p2[1].x, p2[1].y, 
                                           p2[2].x, p2[2].y, 
                                           p2[3].x, p2[3].y);
}

