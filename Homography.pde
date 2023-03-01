/*=========================================================================
 
 Name:        Homography.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Computes a homography from four user-controlled control
              points in one image (the source) to the corners of
              another image (the destination).  Uses the Java Advanced
              Imaging library to compute the transform.
 
=========================================================================*/


// Import Java Advanced Imaging library so we have access to their PerspectiveTransform class
import javax.media.jai.*;


class Homography {
  // The source image
  private PImage image1;
  
  // The destination image
  private PImage image2;
  
  // Four control points in the source image
  private PVector[] p1;
 
  // Four corners of the destination image
  private PVector[] p2; 
  
  // Transform from the source to the destination
  private PerspectiveTransform matrix;
   
  // Per-pixel mappings from destination to source image
  private int[][][] p2p;
  
  // Currently selected point
  private PVector currentP = null;
  private PVector oldMouse;
  
  // Control point radius
  private float radius = 20;
  
  private int drawingMode = 0;
  
  
  Homography(PImage source, int destinationWidth, int destinationHeight) {
    image1 = source;    
    
    // Start with the moveable control points near the edge of the source image
    p1 = new PVector[4];     
    p1[0] = new PVector(image1.width * 0.1, image1.height * 0.1);
    p1[1] = new PVector(image1.width * 0.1, image1.height * 0.9);
    p1[2] = new PVector(image1.width * 0.9, image1.height * 0.9);
    p1[3] = new PVector(image1.width * 0.9, image1.height * 0.1);
    
    SetDestinationSize(destinationWidth, destinationHeight);
  }
  
  
  public void SetDestinationSize(int destinationWidth, int destinationHeight) {
    // Create the destination image
    image2 = new PImage(destinationWidth, destinationHeight);
    
    // Set the corners of the destination image
    p2 = new PVector[4];
    p2[0] = new PVector(0,            0);
    p2[1] = new PVector(0,            image2.height);
    p2[2] = new PVector(image2.width, image2.height);
    p2[3] = new PVector(image2.width, 0);
    
    // Compute the transform
    p2p = new int[image2.width][image2.height][2];
    ComputeTransform();
  }
  
  
  public PImage GetTransformedImage() {    
    // Loop over destination image pixels
    for (int x = 0; x < image2.width; x++) {
      for (int y = 0; y < image2.height; y++) {        
        // Set the destination pixel value
        image2.set(x, y, image1.get(p2p[x][y][0], p2p[x][y][1]));
      } 
    } 
    
//    image2.filter(BLUR, 2);
    
    return image2;
  }
  
  
  public void Draw() {    
    imageMode(CORNERS);
      
    if (drawingMode == 0) {      
      // Draw the source image
      image(image1, 0, 0, image1.width, image1.height); 
      
      // Draw the control points
      strokeWeight(1);
      stroke(1.0, 0.0, 0.0, 0.5);
      fill(1.0, 1.0, 1.0, 0.5);
      
      beginShape(QUADS);
          println(p1);
      vertex(p1[0].x, p1[0].y);
      vertex(p1[1].x, p1[1].y);
      vertex(p1[2].x, p1[2].y);
      vertex(p1[3].x, p1[3].y);
      
      endShape();
          
      for (int i = 0; i < p1.length; i++) {    
        strokeWeight(2);
        stroke(1.0, 0.0, 0.0, 0.5);
        noFill();
        ellipse(p1[i].x, p1[i].y, radius, radius);
      } 
    }
    else {
      // Draw the transformed image
      GetTransformedImage();
      
      image(image2, 0, 0, image2.width, image2.height);
    }
  }
  
  public void ToggleDrawingMode() {
    drawingMode = drawingMode == 0 ? 1 : 0; 
  }
  
  
  public void MousePressed(int x, int y) {
    PVector m = new PVector(x, y);
    
    // Pick control points
    for (int i = 0; i < p1.length; i++) {
      if (PVector.dist(m, p1[i]) <= radius) {
        currentP = p1[i];
        break;
      } 
    }
    
    oldMouse = m;
  }
  
  public void MouseReleased() {
    currentP = null; 
  }
  
  public void MouseDragged(int x, int y) {
    if (currentP == null) return;
    
    PVector m = new PVector(x, y);  
    PVector v = PVector.sub(m, oldMouse);
    
    currentP.add(v);
    
    oldMouse = m.get();
      
    ComputeTransform();
  }
  
  
  private void ComputeTransform() {
    // Compute the matrix
    matrix = PerspectiveTransform.getQuadToQuad(p2[0].x, p2[0].y, 
                                                p2[1].x, p2[1].y, 
                                                p2[2].x, p2[2].y, 
                                                p2[3].x, p2[3].y,
                
                                                p1[0].x, p1[0].y, 
                                                p1[1].x, p1[1].y, 
                                                p1[2].x, p1[2].y, 
                                                p1[3].x, p1[3].y);
                                                
    // Set the per-pixel mappings
    float[] pp1 = new float[2];
    float[] pp2 = new float[2];
    
    for (int x = 0; x < image2.width; x++) {
      for (int y = 0; y < image2.height; y++) {
        // The destination pixel
        pp2[0] = x;
        pp2[1] = y;
        
        // Compute the source pixel
        // XXX: Can probably speed this up by doing all in one call
        matrix.transform(pp2, 0, pp1, 0, 1);
        
        p2p[x][y][0] = (int)pp1[0];
        p2p[x][y][1] = (int)pp1[1];
      }
    }    
  }
}
