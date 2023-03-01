/*=========================================================================
 
 Name:        FluidSimulation.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Class for viscoelastic fluid simulation.
              Based on "Particle-based Viscoelastic Fluid Simulation,"
              Clavet et al. 2005.
 
=========================================================================*/


class FluidSimulation {
  // Gravity
  private float gravity = 9.8;
  
  // Interaction radius
  private float h = 0.5;
  
  // Viscosity parameters
  private float sigma = 0.0;
  private float beta = 0.01;
  
  // Spring parameters
  private float kSpring = 0.3;
  private float alpha = 0.3;
  private float gamma = 0.1;  
  
  // Double-density relaxation parameters
//  private float p0 = 10.0;
//  private float k = 0.004;
//  private float kNear = 0.01; 
  private float p0 = 10.0;
  private float k = 0.12;
  private float kNear = 0.3;
    
  // Friction
  private float u = 0.0;
    
   
  public boolean useViscoelasticity = false;
    
  
  // The particles
  private List<Particle> particles;
  private Set<ParticlePair> pairs;
  private Set<Spring> springs;
  
  // Spatial hash table for particles to improve performance 
  private SpatialHashTable hashTable;
  
  
  FluidSimulation() {    
    particles = new ArrayList<Particle>();
    pairs = new HashSet<ParticlePair>();
    springs = new HashSet<Spring>();
    
    hashTable = new SpatialHashTable();
    hashTable.SetGridSize(h);
  }

  public List<Particle> GetParticles() {
    return particles;
  }


  // XXX: A bit of a hack to make user interaction with the keyboard possible
  public int GetNumberOfParameters() {
    return 11;
  }
  
  public String GetParameterName(int i) {
    String s = new String();
    
    switch (i) {
      case 0:
        return "gravity";
        
      case 1:
        return "h";
        
      case 2:
        return "sigma";
        
      case 3:
        return "beta";
        
      case 4:
        return "kSpring";
        
      case 5:
        return "alpha";
        
      case 6:
        return "gamma";
        
      case 7:
        return "p0";
        
      case 8:
        return "k";
        
      case 9:
        return "kNear";
        
      case 10:
        return "u";

      default:
        return "";   
    }
  }
  
  public float GetParameterValue(int i) {
    switch (i) {
      case 0:
        return gravity;
        
      case 1:
        return h;
        
      case 2:
        return sigma;
        
      case 3:
        return beta;
        
      case 4:
        return kSpring;
        
      case 5:
        return alpha;
        
      case 6:
        return gamma;
        
      case 7:
        return p0;
        
      case 8:
        return k;
        
      case 9:
        return kNear;
        
      case 10:
        return u;

      default:
        return 0.0;   
    }
  }
  
  public void IncrementParameter(int i) {        
    switch (i) {
      case 0:
        gravity += 0.1;
        break;
        
      case 1:
        h += 0.01;
        hashTable.SetGridSize(h);
        break;        
        
      case 2:
        sigma += 0.1;
        break;
        
      case 3:
        beta += 0.1;
        break;
        
      case 4:
        kSpring += 0.1;
        break;
        
      case 5:
        alpha += 0.1;
        break;        
        
      case 6:
        gamma += 0.1;
        break;
        
      case 7:
        p0 += 1;
        break;
        
      case 8:
        k += 0.01;
        break;        
        
      case 9:
        kNear += 0.1;
        break;   
        
      case 10:
        u += 0.1;
        break;
    }      
  }
  
  public void DecrementParameter(int i) {
    switch (i) {
      case 0:
        gravity -= 0.1;
        break;
        
      case 1:
        h -= 0.01;
        h = max(0.0, h);
        hashTable.SetGridSize(h);
        break;        
        
      case 2:
        sigma -= 0.1;
        break;
        
      case 3:
        beta -= 0.1;
        break;
        
      case 4:
        kSpring -= 0.1;
        break;
        
      case 5:
        alpha -= 0.1;
        break;        
        
      case 6:
        gamma -= 0.1;
        break;
        
      case 7:
        p0 -= 1;
        break;
        
      case 8:
        k -= 0.01;
        break;        
        
      case 9:
        kNear -= 0.1;
        break;   
        
      case 10:
        u -= 0.1;
        break;
    }   
  }
  
  
  public void AddParticle(PVector pos, PVector vel) {
    Particle p = new Particle(pos, vel);
    
    particles.add(p);
    
    hashTable.AddParticle(p);
  }
  
  public void Update(float dt, DistanceField df) {
    // Apply gravity
    for (Particle p : particles) {
      p.ApplyGravity(dt);
    }
    
    
    // Update neighborhoods
    hashTable.UpdateNeighborhoods();
    
    
    // Generate particle pairs if using viscoelasticity
    if (useViscoelasticity) {
      GeneratePairs();
    }
    
    
    // Remove any off-screen particles.  Should be done immediately after GeneratePairs().
    RemoveParticles(); 
    
    
    // Apply viscosity
    if (useViscoelasticity) {
      ApplyViscosity(dt);
    }
      
    
    // Apply velocity
    for (Particle p : particles) {
      p.ApplyVelocity(dt);
    }
    
    
    // Update springs if using viscoelasticity.
    if (useViscoelasticity) {
      // Adjust springs
      AdjustSprings(dt);
    
      // Apply spring displacements
      ApplySprings(dt);
    }
    
    
    // Perform double density relaxation
    DoubleDensityRelaxation(dt);
    
    
    // Resolve collisions
    for (Particle p : particles) {
      p.ResolveCollisions(shadowImage.GetShadow(), dt);
    }
   
    // Compute next velocity and rehash
    for (Particle p : particles) {
      p.vel = PVector.sub(p.pos, p.oldPos);
      p.vel.div(dt);
      
      //p.vel.mult(p.velScale);
      //p.vel.y *= p.velScale;
      
      hashTable.RehashParticle(p);
    } 
  }
  

  private void GeneratePairs() {
    // First update current pairs
    Iterator<ParticlePair> it = pairs.iterator();
    while (it.hasNext()) {    
      ParticlePair pair = it.next();
      Particle pi = pair.pi;
      Particle pj = pair.pj;
      
      // First check for onscreen particles, remove pair if one is not onscreen
      if (!pi.OnScreen() || !pj.OnScreen()) {
        it.remove();
        continue; 
      }
      
      // Vector from i to j
      pair.r = PVector.sub(pj.pos, pi.pos);  
      
      // Distance ratio
      pair.q = pair.r.mag() / h;
      
      if (pair.q < 1.0) {
        pair.r.normalize();
      }
      else {
        it.remove(); 
      }
    }
    
    // Now check neighbors
    for (Particle pi : particles) {            
      List<Particle> neighbors = hashTable.GetNeighborhood(pi);
      
      for (Particle pj : neighbors) { 
        if (pi.hashCode() > pj.hashCode()) {
          // Only care about i < j
          continue;
        }
        
        if (!pi.OnScreen() || !pj.OnScreen()) {
          // No need to add
          continue;          
        }
       
        if (pairs.contains(new ParticlePair(pi, pj))) {
          // Already there
          continue; 
        }
       
        // Vector from i to j
        PVector r = PVector.sub(pj.pos, pi.pos);  
        
        // Distance ratio
        float q = r.mag() / h;
        
        if (q < 1.0) {            
          // Make r a unit vector
          r.normalize();
          
          // Add to pairs
          pairs.add(new ParticlePair(pi, pj, r, q));        
        }
      }
    }  
  }
  
  
  private void RemoveParticles() {  
    // Remove any off-screen particles
    for (int i = 0; i < particles.size(); i++) {
      if (!particles.get(i).OnScreen()) {
        hashTable.RemoveParticle(particles.get(i));
        particles.remove(i);
        i--;
      }
    } 
  }
  

  private void ApplyViscosity(float dt) {      
    for (ParticlePair pair : pairs) {
      Particle pi = pair.pi;
      Particle pj = pair.pj;
      
      PVector r = pair.r;
       
      // Velocity difference
      PVector v = PVector.sub(pi.vel, pj.vel);
      
      // Inward radial velocity
      float u = v.dot(r); 
      
      if (u > 0.0) {
        float q = pair.q;
        
        // Linear and quadratic impulses
        r.mult(dt * (1 - q) * (sigma * u + beta * pow(u, 2)));
        r.mult(0.5);
        
        pi.vel.sub(r);
        pj.vel.add(r);
      }
    }      
  }
  
  
  private  void AdjustSprings(float dt) {
    // Add springs for pairs that don't have one
    for (ParticlePair pair : pairs) {      
      Spring s = new Spring(pair, h);
      
      // Should only add if not already there
      springs.add(s);
    }
    
    // Remove springs for pairs that no longer exist
    Iterator<Spring> it = springs.iterator();
    while (it.hasNext()) {
      Spring s = it.next();      
      if (!pairs.contains(s.pair)) {
        it.remove(); 
      }
    }
      
    // Adjust springs
    for (Spring s : springs) {
      ParticlePair pair = s.pair;
      
      Particle pi = pair.pi;
      Particle pj = pair.pj;
   
      float L = s.L;
      float rMag = pair.r.mag();
   
      float d = gamma * L;
      if (rMag > L + d) {
        // Stretch
        s.L += dt * alpha * (rMag - L - d);
      }
      else if (rMag < L - d) {
        // Compress
        s.L -= dt * alpha * (L - d - rMag);
      }       
    }   
    
    // Remove springs
    it = springs.iterator();
    while (it.hasNext()) {
      Spring s = it.next();      
      if (s.L > h) {
        it.remove();         
      }
    }
  }
  
  
  private void ApplySprings(float dt) {    
    for (Spring s : springs) {
      ParticlePair pair = s.pair;
      
      Particle pi = pair.pi;
      Particle pj = pair.pj;
      
      float L = s.L;
      PVector r = pair.r;
      
      PVector D = PVector.mult(r, pow(dt, 2) * kSpring * (1.0 - L / h) * (L - r.mag()));
      D.mult(0.5);
      
      pi.pos.sub(D);
      pj.pos.add(D);
    }
  }
  
  
 private void DoubleDensityRelaxation(float dt) {
    // Double density relaxation
    for (Particle pi : particles) {
      
      float p = 0.0;
      float pNear = 0.0;
      
      List<Particle> neighbors = hashTable.GetNeighborhood(pi);
      
      for (Particle pj : neighbors) {   
        if (pi == pj) continue;
        
        // Vector from i to j
        PVector r = PVector.sub(pj.pos, pi.pos);
              
        // Distance ratio
        float q = r.mag() / h;
        
        if (q < 1.0) {
          // Compute density and near-density
          p += pow(1.0 - q, 2);
          pNear +=  pow(1.0 - q, 3);
        }
      }
      
     
      // Compute pressure and near-pressure    
      float P = k * (p - p0);
      float PNear = kNear * pNear;
      
      PVector dx = new PVector(0.0, 0.0);
      for (Particle pj : neighbors) {
        if (pi == pj) continue;
        
        // Vector from i to j
        PVector r = PVector.sub(pj.pos, pi.pos);
        
        // Distance ratio
        float q = r.mag() / h;
        
        if (q < 1.0) {
          r.normalize();
          
          // Apply displacements
          r.mult(pow(dt, 2) * (P * (1.0 - q) + PNear * pow(1.0 - q, 2)));
          r.mult(0.5);
          
          pj.pos.add(r);
          dx.sub(r);
        }
      }
      
      pi.pos.add(dx);
    } 
  }
  
  
  //
  // Class to hold information for a spring between particles.
  //
  private class Spring {
    // The particle pair
    ParticlePair pair;
   
    // Rest length
    float L;
    
    Spring(ParticlePair pair) {
      this.pair = pair;
    }
   
    Spring(ParticlePair pair, float L) {
      this.pair = pair;
      this.L = L; 
    }
 
    public boolean equals(Object other) {
      if (this == other) {
        return true;
      }
      
      if (other == null || getClass() != other.getClass()) {
        return false; 
      }
      
      final Spring otherSpring = (Spring)other;
      
      return pair == otherSpring.pair;
    }
    
    public int hashCode() {
      return pair.hashCode();
    }
  }
  
  //
  // Class to hold information for pairs of particles.
  //
  private class ParticlePair {
    Particle pi;
    Particle pj;
    
    PVector r;
    float q;
    
    ParticlePair(Particle pi, Particle pj, PVector r, float q) {
      this.pi = pi;
      this.pj = pj;
      
      this.r = r;
      this.q = q;
    }
    
    ParticlePair(Particle pi, Particle pj) {
//      this(pi, pj, new PVector(), 0.0);
      this.pi = pi;
      this.pj = pj;
    }
  
    public boolean equals(Object other) {
      if (this == other) {
        return true;
      }
      
      if (other == null || getClass() != other.getClass()) {
        return false; 
      }
      
      final ParticlePair otherPair = (ParticlePair)other;
      
      return (pi == otherPair.pi && pj == otherPair.pj) ||
             (pi == otherPair.pj && pj == otherPair.pi);
    }
    
    public int hashCode() {
      return pi.hashCode() ^ pj.hashCode();
    }
  }
  
  
  //
  // Class to hold information for a particle.
  //
  public class Particle {
    // Position and velocity
    PVector pos;
    PVector oldPos;
    PVector vel;
    
    // Bit of a hack to be able to reduce the calculated velocity when extracting
//    float velScale;
    
    Particle(PVector pos, PVector vel) {
      this.pos = pos.get();
      oldPos = pos.get();
      
      this.vel = vel.get();
    }     
  
    public boolean OnScreen() {
      return pos.x >= 0 && pos.x < screenWidth && pos.y < height * pixels2screen;
    }    
  
    public void ApplyGravity(float dt) {
      // Compute gravity
      vel.y += gravity * dt;
    }
    
    public void ApplyVelocity(float dt) {  
      // Save previous position
      oldPos = pos.get();
      
      // Reset velocity scale
//      velScale = 1.0;
          
      // Advance to predicted position
      pos.add(PVector.mult(vel, dt));
    }
  
    public void ResolveCollisions(PImage image, float dt) {
      // Compute intersection with shadow
      int[] imagePos = Screen2Pixels(pos);
      int x = imagePos[0];
      int y = imagePos[1];
          
      if (distanceField.InObject(x, y)) {
        // Get the distance field gradient
        PVector n = distanceField.GetGradient(x, y);
//        PVector n = distanceField.GetVector(x, y);
        
        // Use the gradient as the suface normal
        n.normalize();
        
        // Compute velocity components
        PVector vNorm = PVector.mult(n, vel.dot(n));      
        PVector vTan = PVector.sub(vel, vNorm);
        vTan.mult(u);
  
        // Compute the impulse
        // XXX: I think there is an error in the paper.  We need to add the fractional tangent here,
        //      then subtract the impulse
        PVector I = PVector.add(vNorm, vTan);

        pos.sub(PVector.mult(I, dt));
       
        // See if we are outside
        imagePos = Screen2Pixels(pos);
        x = imagePos[0];
        y = imagePos[1];
        
        if (distanceField.InObject(x, y)) {
          // Extract the particle from the object using the distance field 
          Extract(dt);   
        }
      }
    }
  
  
    private void Extract(float dt) {
      int[] imagePos = Screen2Pixels(pos);
      int x = imagePos[0];
      int y = imagePos[1];
 
      // Use distance field directly
      PVector v = distanceField.GetVector(x, y);
      pos.add(Pixels2Screen(v));
      
      // Scale velocity to reduce "splashing"
//      velScale = 0.5;
    }
  }
  
  
  //
  // Class for 2D spatial hash table.
  // Based on "Optimized Spatial Hashing for Collision Detection of Deformable Objects," Teschner et al., 2003.
  //
  private class SpatialHashTable {
    // Grid size controlling how many points map to the same grid cell
    private float gridSize = 1.0;
    
    // Large prime numbers for hashing
    private final int p1 = 73856093;
    private final int p2 = 19349663;
    
    // XXX: Would be nice to make this more generic...
    private List<List<Particle>> hashTable;
    
    private Set<Integer> activeCells;
    private List<List<Particle>> neighborHoods;

    
    SpatialHashTable() {
      hashTable = new ArrayList<List<Particle>>(); 
      activeCells = new HashSet<Integer>();
      neighborHoods = new ArrayList<List<Particle>>();
      
      // XXX: Need to experiment with this value...
      SetHashTableSize(1009);
    }
    
    public void SetHashTableSize(int s) {      
      // Save all current particles for rehashing
      List<Particle> particles = new ArrayList<Particle>();
      for (List<Particle> list : hashTable) {
        for (Particle p : list) {
          particles.add(p);
        } 
      }
      
      // Resize the hashtable
      hashTable = new ArrayList<List<Particle>>();
      for (int i = 0; i < s; i++) {
        hashTable.add(new ArrayList<Particle>());
      }      
      
      // Resize the neighborhood list
      activeCells.clear();      
      neighborHoods = new ArrayList<List<Particle>>();
      for (int i = 0; i < s; i++) {
        neighborHoods.add(new ArrayList<Particle>());
      }
      
      // Add the particles
      for (Particle p : particles) {
        AddParticle(p); 
      }
    }
    
    public void SetGridSize(float s) {
      gridSize = s; 
      
      // Get all current particles and clear hash table
      List<Particle> particles = new ArrayList<Particle>();
      for (List<Particle> list : hashTable) {
        for (Particle p : list) {
          particles.add(p);
        } 
        
        list.clear();
      }
      
      // Clear neighborhoods
      activeCells.clear();      
      for (List<Particle> list : neighborHoods) {       
        list.clear();
      }
      
      // Add the particles
      for (Particle p : particles) {
        AddParticle(p); 
      }
    }
    
    public void AddParticle(Particle p) {    
      // Add to grid cell
      int hash = HashFunction(p.pos.x, p.pos.y);
      hashTable.get(hash).add(p);
      
      if (hashTable.get(hash).size() == 1) {
        // Add to active cells
        activeCells.add(hash);
      }
    }
    
    public void RehashParticle(Particle p) {
      int oldHash = HashFunction(p.oldPos.x, p.oldPos.y);
      int newHash = HashFunction(p.pos.x, p.pos.y);
      
      if (newHash != oldHash) {      
        // Remove from previous grid cell
        hashTable.get(oldHash).remove(p);
        
        if (hashTable.get(oldHash).size() == 0) {
          // Remove from active cells
          activeCells.remove(oldHash);
        }
        
        // Add to new grid cell    
        hashTable.get(newHash).add(p);
        
        if (hashTable.get(newHash).size() == 1) {
          // Add to active cells
          activeCells.add(newHash);
        }
      }
    }
    
    public void RemoveParticle(Particle p) {
      int hash = HashFunction(p.pos.x, p.pos.y);
      hashTable.get(hash).remove(p); 
      
      if (hashTable.get(hash).size() == 0) {
        // Remove from active cells
        activeCells.remove(hash);
      }
    }
    
    public void UpdateNeighborhoods() {
      for (Integer i : activeCells) {
        neighborHoods.set(i.intValue(), GetNeighbors(hashTable.get(i).get(0)));
      }
    }
    
    public List<Particle> GetNeighborhood(Particle p) {
      return neighborHoods.get(HashFunction(p.pos.x, p.pos.y)); 
    }
    
    public List<Particle> GetNeighbors(Particle p) {
      List<Particle> neighbors = new ArrayList<Particle>();
    
      // Add all particles in the same grid cell and 8 neighboring grid cells
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x           , p.pos.y           )));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x           , p.pos.y + gridSize)));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x           , p.pos.y - gridSize)));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x + gridSize, p.pos.y           )));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x + gridSize, p.pos.y + gridSize)));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x + gridSize, p.pos.y - gridSize)));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x - gridSize, p.pos.y           )));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x - gridSize, p.pos.y + gridSize)));
      neighbors.addAll(hashTable.get(HashFunction(p.pos.x - gridSize, p.pos.y - gridSize)));
      
      neighbors.remove(p);
      
      return neighbors;
    }
    
    public int GetNumberOfParticles() {
      int n = 0;
      for (List<Particle> list : hashTable) {
        n += list.size();
      }
      
      return n;
    }
    
    public int GetNumberOfGridCells() {           
      return activeCells.size();     
    }
    
    private int HashFunction(float x, float y) {
      int i = floor(x / gridSize);
      int j = floor(y / gridSize);
      
      int h = ((i * p1) ^ (j * p2)) % hashTable.size();
      
      // Check for negative hash.  If so, wrap around
      if (h < 0) {
        h += hashTable.size(); 
      }
     
      return h; 
    }
  }
  
  void Reset() {
    for (int i = 0; i < particles.size(); i++) {
      hashTable.RemoveParticle(particles.get(i));
      particles.remove(i);
      i--;
    } 
  }
}
