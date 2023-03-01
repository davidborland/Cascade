/*=========================================================================
 
 Name:        Source.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Source of water particles.
 
=========================================================================*/


class Source {
  // Droplets to add per second
  private float flow = 40.0; 
  
  // Counter for flow
  private float flowCount = 0;
  
  // Source position and radius
  public PVector pos;
  public float radius;
  public float[] velocityRange;  // [xMin, xMax, yMin, yMax]
  
  
  // Fluid simulation
  private FluidSimulation fluid;
  
  
  Source(float posX, float posY, float radius, float[] velocityRange, FluidSimulation fluid) {
    pos = new PVector(posX, posY);
    this.radius = radius;
    this.velocityRange = velocityRange;
    this.fluid = fluid;
  }
  
  public void Update(float t) {
    // Add new droplets  
    flowCount += flow * t;
    int newDrops = floor(flowCount);
  
    for (int i = 0; i < newDrops; i++) {   
      fluid.AddParticle(NewPosition(), NewVelocity());
    }
  
    flowCount -= newDrops;    
  
  /* 
   if (addParticles && fluid.particles.size() > 1000) addParticles = false;
   if (!addParticles && fluid.particles.size() < 200) addParticles = true;
   
   if (addParticles) {
     for (int i = 0; i < 2; i++) {
       fluid.AddParticle(source.NewPosition(), source.NewVelocity());   
     }
   }
   */
  }
  
  public void IncrementFlow() {
    flow += 10.0;
  }
  
  public void DecrementFlow() {
    flow -= 10.0;
    flow = max(flow, 0.0);
  }
 
  public void Draw() {     
    noFill();
    stroke(0.0, 0.0, 0.0, 0.25);
    strokeWeight(1);
    ellipse(pos.x, pos.y, radius * 2.0, radius * 2.0);
  } 
   
  public boolean IsInside(PVector p) {
    return p.dist(pos) <= radius;
  } 
  
  private PVector NewPosition() {   
    float r = 0.01;
    return PVector.add(pos, new PVector(random(-r, r), random(-r, r)));     
  }
  
  private PVector NewVelocity() {
    return new PVector(random(velocityRange[0], velocityRange[1]), random(velocityRange[2], velocityRange[3]));
  }
}
