/*=========================================================================
 
 Name:        Building.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Classes for controlling the house and factory.
 
=========================================================================*/

class Building {
  PImage building;
  PImage pipe;
  PImage active;
  
  String buildingFilename;
  String pipeFilename;
  String activeFilename;
  
  // Position of building in screen coordinates.
  PVector pos;
  float scale;
  
  // Location and radius, in pixels, of target in for putting water in pipe, relative to base position
  PVector targetOffset;
  float targetRadius;
  
  // Exit location for particles
  PVector exitOffset;
  
  // Number of particles that have entered the pipe
  int particleCount;
  
  Building(String buildingImage, String pipeImage, String activeImage) {
    buildingFilename = buildingImage;
    pipeFilename = pipeImage;
    activeFilename = activeImage;
    
    targetOffset = new PVector(0, 0);
    targetRadius = 0;
    exitOffset = new PVector(0, 0);
    
    pos = new PVector(0, 0);
    scale = 1.0;
    
    particleCount = 0;
  }
  
  void LoadImages() {    
    building = loadImage(buildingFilename);
    pipe = loadImage(pipeFilename);
    active = loadImage(activeFilename);    
  }
  
  void SetPosition(PVector p) {
    pos = p; 
  }
  
  void SetScale(float s) {
    scale = s; 
  }
  
  void ProcessParticles(List<FluidSimulation.Particle> particles) {
    PVector targetPos = PVector.add(pos, targetOffset);
    float r2 = targetRadius * targetRadius;
    
    PVector exitPos = PVector.add(pos, exitOffset);
  
    for (FluidSimulation.Particle p : particles) {
      PVector d = PVector.sub(p.pos, targetPos);
      
      if (d.magSq() <= r2) {
        particleCount++;
        
        float r = 0.01;     
        p.pos.set(PVector.add(exitPos, new PVector(random(-r, r), random(-r, r))));
        p.oldPos.set(p.pos);
        p.vel.set(0.0, 0.0);
      }
    }
  }
  
  void Reset() {
    particleCount = 0;
  }

  void Draw() {
    imageMode(CENTER);
    
    pushMatrix();    
    
    scale(screen2pixels);
    translate(pos.x, pos.y);
    
    // Images
    pushMatrix();
    scale(scale * pixels2screen);
    
    // Pipe
    tint(1.0, (float)particleCount / particleCountThreshold);
    image(pipe, 0, 0);
    tint(1.0, 1.0);
    
    // Active 
    if (particleCount >= particleCountThreshold) {
      image(active, 0, 0); 
    }
    
    // Building
    image(building, 0, 0);
    
    popMatrix();
   
    // Target and exit for debugging
/*    
    fill(0, 0, 0, 0.5);
    noStroke();
    ellipse(targetOffset.x, targetOffset.y, targetRadius * 2.0, targetRadius * 2.0);
    ellipse(exitOffset.x, exitOffset.y, targetRadius, targetRadius);
*/    
    popMatrix();    
  }
}


