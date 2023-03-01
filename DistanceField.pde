/*=========================================================================
 
 Name:        DistanceField.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Class for computing the distance field of an input image.
              Based on http://www.codersnotes.com/notes/signed-distance-fields
 
=========================================================================*/


class DistanceField {
  // Grid of values
  private DFPoint[][] g;
 
  // Size of grid
  private int w;
  private int h;
  
  // Amount of downsampling from original image
  private int downSampling;
 
 
  DistanceField() { 
    w = 0;
    h = 0;
    
    downSampling = 1;
  }  
  
  public boolean InObject(int x, int y) {
    x = I2G(x);
    y = I2G(y);  
    
    return x >= 1 && x < w - 1 &&
           y >= 1 && y < h - 1 &&
           g[x][y].d < 0;
  }
  
  public PVector GetGradient(int x, int y) {   
    // Input x and y are in original image coordinates, so convert to grid
    x = I2G(x);
    y = I2G(y);
    
    // XXX: Should this be necessary?  Issue with I2G???
    if (x < 1) x = 1;
    if (x > w - 2) x = w - 2;
    if (y < 1) y = 1;
    if (y > h - 2) y = h - 2;
    
    // Compute the gradient using the sobel operator
    float dx = g[x+1][y-1].d + 2.0*g[x+1][y].d + g[x+1][y+1].d - 
               g[x-1][y-1].d - 2.0*g[x-1][y].d - g[x-1][y+1].d;
               
    float dy = g[x-1][y+1].d + 2.0*g[x][y+1].d + g[x+1][y+1].d -
               g[x-1][y-1].d - 2.0*g[x][y-1].d - g[x+1][y-1].d; 

    return new PVector(dx, dy);                 
  }
  
  public PVector GetVector(int x, int y) {     
    // Use gradient
    PVector v = GetGradient(x, y);
    
    x = I2G(x);
    y = I2G(y);
    
    v.normalize();   
    
    // Correct for downSampling
    v.mult((-(g[x][y].d + 1)) * downSampling);
    
    return v;
/*
    x = I2G(x);
    y = I2G(y);

    // Use distance vector directly
    return new PVector(g[x][y].dx, g[x][y].dy);
*/    
  }
  
  public void GenerateDF(PImage image, boolean interior) {
    // Assuming an input image with a white background and black objects.
    
    
    // Allocate memory if necessary
    if (w != image.width + 2 ||
        h != image.height + 2) {
      // Set new internal variables
      downSampling = width / image.width;  
          
      w = image.width + 2;
      h = image.height + 2;
  
      // Allocate memory for grid    
      g = new DFPoint[w][h];
    
      for (int x = 0; x < w; x++) {
        for (int y = 0; y < h; y++) {      
          g[x][y] = new DFPoint();
        }
      }    
    }
    
    
    // If interior is true, the (negative) distance of pixels inside objects to the object edge is calculated.
    // If interior is false, the (positive) distance of pixels outside objects to the object edge is calculated.
    int inside;
    int outside;
    
    final int black = 0;
    final int white = 9999;
    
    if (interior) {
      inside = white;
      outside = black; 
    }
    else {
      inside = black;
      outside = white;
    }
    
    
    // Create border
    for (int x = 0; x < w; x++) {
      g[x][0].dx = white;
      g[x][0].dy = white;
      g[x][h - 1].dx = white;
      g[x][h - 1].dy = white;
    }
    for (int y = 0; y < h; y++) {
      g[0][y].dx = white;
      g[0][y].dy = white;
      g[w - 1][y].dx = white;
      g[w - 1][y].dy = white;
    }
    
    // Copy image to grid    
    for (int x = 0; x < image.width; x++) {
      for (int y = 0; y < image.height; y++) {
        int v = red(image.pixels[y * image.width + x]) < 0.5 ? inside : outside;

        g[x + 1][y + 1].dx = v;
        g[x + 1][y + 1].dy = v;
      }
    }

        
    // Pass 0
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        if ((interior && g[x][y].DistSq() == outside) ||
           (!interior && g[x][y].DistSq() == inside )) continue;
        Compare(x, y, -1,  0);
        Compare(x, y,  0, -1);
        Compare(x, y, -1, -1);
        Compare(x, y,  1, -1);
      }
 
      for (int x = w - 2; x > 0; x--) {
        if ((interior && g[x][y].DistSq() == outside) ||
           (!interior && g[x][y].DistSq() == inside )) continue; 
        
        Compare(x, y,  1,  0);
      }
    }
 
    // Pass 1
    for (int y = h - 2; y > 0; y--) {
      for (int x = w - 2; x > 0; x--) {
        if ((interior && g[x][y].DistSq() == outside) ||
           (!interior && g[x][y].DistSq() == inside )) continue;
        
        Compare(x, y,  1,  0);
        Compare(x, y,  0,  1);
        Compare(x, y, -1,  1);
        Compare(x, y,  1,  1);
      }
 
      for (int x = 1; x < w - 1; x++) {
        if ((interior && g[x][y].DistSq() == outside) ||
           (!interior && g[x][y].DistSq() == inside )) continue;
        
        Compare(x, y, -1,  0);
      }
    }
    
    
    // XXX: Don't need this if just using the distance vector...   
    
    // Store the distances
    float s = interior ? -1.0 : 0.0;
    
    for (int x = 0; x < w; x++) {
      for (int y = 0; y < h; y++) {
        g[x][y].d = sqrt(g[x][y].DistSq()) * s;
      }
    }    
  }
  
  public void CopyToImage(PImage image) {    
    // Find min and max values
    float min = 0.0;
    float max = 0.0;
    for (int x = 1; x < w - 1; x++) {
      for (int y = 1; y < h - 1; y++) {
        float v = -sqrt(g[x][y].DistSq());
        g[x][y].d = v;
      
        if (v < min) min = v;
        if (v > max) max = v;
      }
    }  
  
    // Copy scaled distance values to image
    // Assuming image size equals grid size
    for (int x = 0; x < image.width; x++) {
      for (int y = 0; y < image.height; y++) {
//        float v = g[I2G(x)][I2G(y)].d;
float v = g[x + 1][y + 1].d;
        v = (v - min) / (max - min);
        
        image.set(x, y, color(v, v, v));
      } 
    }
  }
  
  private void Compare(int x, int y, int xOffset, int yOffset) {
    DFPoint p1 = g[x][y];
    DFPoint p2 = g[x + xOffset][y + yOffset];

    int dx = p2.dx + xOffset;
    int dy = p2.dy + yOffset;
    
    if (dx * dx + dy * dy < p1.DistSq()) {
      p1.dx = dx;
      p1.dy = dy; 
    }
  }
  
  private int I2G(int i) {
    // Add 1 for the border
    return i / downSampling + 1;
  }
  
  private class DFPoint {
    float d;
    
    int dx;
    int dy;
 
    public int DistSq() {
      return dx * dx + dy * dy;
    } 
  }
}
