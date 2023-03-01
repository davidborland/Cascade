/*=========================================================================
 
 Name:        Cascade.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Processing sketch for an interactive exhibit at the 
              Morehead Planetarium showing how water always flows
              downhill.
 
=========================================================================*/


// TODO:
// * Add parameter saving, including calibration
// * Try to mitigate splashing:  look at adding viscoelasticity again, 
//   maybe modulate velocity after extraction

// * INTERACTION.  Try computing velocity vector and using previous frame (just accumulate previous frames???)

// * Use sorted particles for all steps of simulation
// * Save repeated calculations between simulation steps
// * Try GPU-based distance field?
// * Try velocity calculation by distance to previous frame, then sample via distance to current edge.
// * Use distance field to compute intersection based on particle radius


import java.util.*;

boolean useEye = false;

String ConfigFile = "CascadeConfig.txt";


// Parameters
float screenWidth = 7;        // Physical dimension of screen in meters
float screenHeight;
float screen2pixels;
float pixels2screen;

float timeScale = 1.0;

int fluidParameter = 0;

float minFPS = 30.0;

float motionThreshold = 5.0;
float motionTimeout = 60.0;

int particleCountThreshold = 50;

float congratsTimeout = 10.0;

float[] zone1 = { 3, 3.5, 1, 1.5 };
float[] zone2 = { 3, 3.5, 2.5, 3 };
float[] zone3 = { 5.5, 6.0, 2.5, 3 };
float[] zone4 = { 5.5, 6.0, 1, 1.5 };


// Simulation objects
Source source;
FluidSimulation fluid;
ParticleRenderer particleRenderer;
ShadowImage shadowImage;
DistanceField distanceField;
Building house;
Building powerPlant;

// Images
String backgroundFilename;
PImage background;
String congratsFilename;
PImage congrats;
String lightsFilename;
PImage lights;

// Timing
Timer timer;


// Interaction variables
boolean showMenu = false;

PVector oldMouse;

boolean showSource = false;
boolean moveSource = false;

boolean calibrate = false;

boolean showDistanceField = false;

boolean showShadow = false;

float motionCounter = 0.0;
float congratsCounter = 0.0;


void setup() {  
  // Processing setup
  size(1280, 768, P3D);      // Projector resolution

  // For full screen
//size(displayWidth, displayHeight, P3D);

  noSmooth();              // XXX: This is a hack to get the alpha channel to work correctly in Processing 2.0.2
  colorMode(RGB, 1.0);  
  randomSeed(1);
  
//frameRate(30);  
  pixels2screen = screenWidth / width;
  screen2pixels = width / screenWidth;
  screenHeight = height * pixels2screen;
  
  // Create objects
  timer = new Timer();  
  
  oldMouse = new PVector();
  
  fluid = new FluidSimulation();
  
  float[] v = { 1.0, 2.0, -1.0, 0.0 };
  source = new Source(0.01, 0.25, 0.1, v, fluid);
  
  particleRenderer = new ParticleRenderer();
  particleRenderer.SetParticles(fluid.GetParticles());
  
  shadowImage = new ShadowImage(this, useEye);
 
  distanceField = new DistanceField();
  
  house = new Building("H_House_Pipe.png", "H_Inside_Pipe_Color.png", "H_Flowers.png");
  powerPlant = new Building("PP_Empty_Pipe.png", "PP_Inside_Pipe_Color.png", "PP_Cloud.png");
  
  backgroundFilename = "background.png";
  background = loadImage(backgroundFilename);
  congratsFilename = "3_4_Congrats_Screen.png";
  congrats = loadImage(congratsFilename);
  lightsFilename = "H_Lights.png";
  lights = loadImage(lightsFilename);
  
  LoadConfiguration();
  
  Reset();
  
  this.registerMethod("dispose", this);
}

void dispose() {
  SaveConfiguration(); 
  shadowImage.SetUseCamera(false);
}

void LoadConfiguration() {
  String f[] = loadStrings(ConfigFile);
  
  if (f == null) return;
  
  for (int i = 0; i < f.length; i++) {
    if (f[i].contains("//")) continue;
    
    String[] s = split(f[i], ' ');
    
    // General parameters
    if (s[0].equals("screenWidth")) {
      screenWidth = int(s[1]);
      pixels2screen = screenWidth / width;
      screen2pixels = width / screenWidth;
    }
    else if (s[0].equals("timeScale")) {
      timeScale = float(s[1]);
    }
    else if (s[0].equals("flow")) {
      source.flow = float(s[1]);
    }
    else if (s[0].equals("distanceFieldDownsampling")) {
      shadowImage.SetDownSampling(int(s[1]));
    }
    else if (s[0].equals("minFPS")) {
      minFPS = float(s[1]);
    }
    else if (s[0].equals("motionThreshold")) {
      motionThreshold = float(s[1]);
    }
    else if (s[0].equals("motionTimeout")) {
      motionTimeout = float(s[1]);
    }
    else if (s[0].equals("particleCountThreshold")) {
      particleCountThreshold = int(s[1]);
    }
    
    // Source
    else if (s[0].equals("sourcePosition")) {
      source.pos.x = float(s[1]);
      source.pos.y = float(s[2]);
    }
    else if (s[0].equals("sourceRadius")) {
      source.radius = float(s[1]);
    }
    else if (s[0].equals("sourceVelocityRange")) {
      source.velocityRange[0] = float(s[1]);
      source.velocityRange[1] = float(s[2]);
      source.velocityRange[2] = float(s[3]);
      source.velocityRange[3] = float(s[4]);
    }
    
    // Particle appearance
    else if (s[0].equals("particleRadius")) {
      particleRenderer.SetRadius(float(s[1]));
    }
    else if (s[0].equals("particleOpacity")) {
      particleRenderer.SetOpacity(float(s[1]));
    }
    else if (s[0].equals("particleDensityThreshold")) {
      particleRenderer.SetDensityThreshold(float(s[1]));
    }
    
    // Camera calibration
    else if (s[0].equals("useCamera")) {
      shadowImage.SetUseCamera(s[1].equals("true") ? true : false);
    }
    else if (s[0].equals("p1_0")) {
      if (shadowImage.homography != null) {
        shadowImage.homography.p1[0].x = float(s[1]);
        shadowImage.homography.p1[0].y = float(s[2]);
      } 
    }
    else if (s[0].equals("p1_1")) {
      if (shadowImage.homography != null) {
        shadowImage.homography.p1[1].x = float(s[1]);
        shadowImage.homography.p1[1].y = float(s[2]);
      } 
    }
    else if (s[0].equals("p1_2")) {
      if (shadowImage.homography != null) {
        shadowImage.homography.p1[2].x = float(s[1]);
        shadowImage.homography.p1[2].y = float(s[2]);
      } 
    }
    else if (s[0].equals("p1_3")) {
      if (shadowImage.homography != null) {
        shadowImage.homography.p1[3].x = float(s[1]);
        shadowImage.homography.p1[3].y = float(s[2]);
      } 
    }
    
    // House
    else if (s[0].equals("houseBuilding")) {
      house.buildingFilename = s[1];
    }
    else if (s[0].equals("housePipe")) {
      house.pipeFilename = s[1];
    }
    else if (s[0].equals("houseLightFlowers")) {
      house.activeFilename = s[1];
    }
    else if (s[0].equals("houseScale")) {
      house.scale = float(s[1]);
    }
    else if (s[0].equals("houseTargetOffset")) {
      house.targetOffset.x = float(s[1]);
      house.targetOffset.y = float(s[2]);
    }
    else if (s[0].equals("houseTargetRadius")) {
      house.targetRadius = float(s[1]);
    }
    else if (s[0].equals("houseExitOffset")) {
      house.exitOffset.x = float(s[1]);
      house.exitOffset.y = float(s[2]);
    }
    
    // Power plant
    else if (s[0].equals("powerPlantBuilding")) {
      powerPlant.buildingFilename = s[1];
    }
    else if (s[0].equals("powerPlantPipe")) {
      powerPlant.pipeFilename = s[1];
    }
    else if (s[0].equals("powerPlantCloud")) {
      powerPlant.activeFilename = s[1];
    }
    else if (s[0].equals("powerPlantScale")) {
      powerPlant.scale = float(s[1]);
    }
    else if (s[0].equals("powerPlantTargetOffset")) {
      powerPlant.targetOffset.x = float(s[1]);
      powerPlant.targetOffset.y = float(s[2]);
    }
    else if (s[0].equals("powerPlantTargetRadius")) {
      powerPlant.targetRadius = float(s[1]);
    }
    else if (s[0].equals("powerPlantExitOffset")) {
      powerPlant.exitOffset.x = float(s[1]);
      powerPlant.exitOffset.y = float(s[2]);
    }
    
    // Congrats
    else if (s[0].equals("congrats")) {
      congratsFilename = s[1];
      congrats = loadImage(congratsFilename); 
    }
    else if (s[0].equals("lights")) {
      lightsFilename = s[1];
      lights = loadImage(lightsFilename); 
    }
  }
  
  // Make sure to recompute the homography in case the calibration has been loaded
  if (shadowImage.homography != null) {
    shadowImage.homography.ComputeTransform(); 
  }
  
  // Make sure to load the building images in case the file names have changed
  house.LoadImages();
  powerPlant.LoadImages();
}

void SaveConfiguration() {
  ArrayList<String> f = new ArrayList<String>();
  
  // General parameters
  f.add("// General parameters");
  f.add("screenWidth " + screenWidth);  
  f.add("timeScale " + timeScale);
  f.add("flow " + source.flow);  
  f.add("distanceFieldDownsampling " + shadowImage.downSampling);
  f.add("minFPS " + minFPS);
  f.add("motionThreshold " + motionThreshold);
  f.add("motionTimeout " + motionTimeout);
  f.add("particleCountThreshold " + particleCountThreshold);
  
  // Source
  f.add("\n// Source");
  f.add("sourcePosition " + source.pos.x + " " + source.pos.y);
  f.add("sourceRadius " + source.radius);
  f.add("sourceVelocityRange " + source.velocityRange[0] + " " 
                               + source.velocityRange[1] + " " 
                               + source.velocityRange[2] + " " 
                               + source.velocityRange[3]);
  
  // Particle appearance
  f.add("\n// Particle appearance");
  f.add("particleRadius " + particleRenderer.GetRadius());
  f.add("particleOpacity " + particleRenderer.GetOpacity());
  f.add("particleDensityThreshold " + particleRenderer.GetDensityThreshold());
  
  // Fluid simulation
  f.add("\n// Fluid simulation");
  f.add("gravity " + fluid.gravity);
  f.add("h " + fluid.h);
  f.add("sigma " + fluid.sigma);
  f.add("beta " + fluid.beta);
  f.add("kSpring " + fluid.kSpring);
  f.add("alpha " + fluid.alpha);
  f.add("gamma " + fluid.gamma);
  f.add("k " + fluid.kNear);
  f.add("u " + fluid.u);
  
  // Camera calibration
  f.add("\n// Camera calibration");
  f.add("useCamera " + shadowImage.GetUseCamera());
  if (shadowImage.homography != null) {
    f.add("p1_0 " + shadowImage.homography.p1[0].x + " " + shadowImage.homography.p1[0].y);
    f.add("p1_1 " + shadowImage.homography.p1[1].x + " " + shadowImage.homography.p1[1].y);
    f.add("p1_2 " + shadowImage.homography.p1[2].x + " " + shadowImage.homography.p1[2].y);
    f.add("p1_3 " + shadowImage.homography.p1[3].x + " " + shadowImage.homography.p1[3].y);
  }
  
  // House
  f.add("\n// House");
  f.add("houseBuilding " + house.buildingFilename);
  f.add("housePipe " + house.pipeFilename);
  f.add("houseLightsFlowers " + house.activeFilename);
  f.add("houseScale " + house.scale);
  f.add("houseTargetOffset " + house.targetOffset.x + " " + house.targetOffset.y);
  f.add("houseTargetRadius " + house.targetRadius);
  f.add("houseExitOffset " + house.exitOffset.x + " " + house.exitOffset.y);
 
  // Power plant
  f.add("\n// Power plant"); 
  f.add("powerPlantBuilding " + powerPlant.buildingFilename);
  f.add("powerPlantPipe " + powerPlant.pipeFilename);
  f.add("powerPlantCloud " + powerPlant.activeFilename);
  f.add("powerPlantScale " + powerPlant.scale);
  f.add("powerPlantTargetOffset " + powerPlant.targetOffset.x + " " + powerPlant.targetOffset.y);
  f.add("powerPlantTargetRadius " + powerPlant.targetRadius);
  f.add("powerPlantExitOffset " + powerPlant.exitOffset.x + " " + powerPlant.exitOffset.y);
  
  // Background
  f.add("background " + backgroundFilename);
  
  // Congrats
  f.add("\n// Congrats");
  f.add("congrats " + congratsFilename);
  f.add("lights " + lightsFilename);
  
  saveStrings(ConfigFile, f.toArray(new String[f.size()]));
}


void draw() {      
  if (calibrate) {    
    // Render homography and return
    background(1.0, 1.0, 1.0, 0.0);
    
    shadowImage.DrawHomography();
   
    return; 
  }
  
  
  // Get the elapsed time  
  timer.Update();
  float dt = timer.GetElapsedTime() * timeScale;
 
// XXX: Testing threshold on elapsed time
//dt = min(dt, 1.0 / 30.0);
//  dt = 1.0 / 30.0;


  // Update shadow image
  shadowImage.Update();
 
  // Motion detection
  if (shadowImage.cameraDiff < motionThreshold) {
    motionCounter += timer.GetElapsedTime();

    if (motionCounter > motionTimeout) {
      Reset(); 
    }
  }
  else {
    motionCounter = 0.0;
  }
  
  // Compute distance field
  distanceField.GenerateDF(shadowImage.GetShadow(), true);
  
  
  // Update the source
  if (timer.GetFPS() >= minFPS) {
    source.Update(dt);
  }


  // Do the physics simulation
  fluid.Update(dt, distanceField);

  
  // Clear the screen 
//  background(0.95, 0.95, 0.9);
//background(1);
//background(background);
image(background, 0, 0, width, height);
    
    
  // Show distance field image
  if (showDistanceField) {        
    // Performance here could be improved, but we don't really care about the framerate here, as it is just for debugging
    PImage distanceFieldImage = new PImage(shadowImage.GetShadow().width, shadowImage.GetShadow().height);
    distanceField.CopyToImage(distanceFieldImage);
    
    image(distanceFieldImage, 0, 0, width, height);
  }  


  // Draw the particles   
  particleRenderer.Draw();
  

  // Draw the shadow image
  if (showDistanceField) {        
    shadowImage.DrawOutlines(); 
  }
  else {
    if (showShadow) {
      shadowImage.DrawShadow();
    }
    else {
      shadowImage.DrawShapes();
    }
  }


  // Draw the source
  if (showSource) {  
    pushMatrix();    
    scale(screen2pixels);
    
    source.Draw();
    
    popMatrix();
  }
  
  
  // Draw menu
  if (showMenu) {
    DrawMenu(); 
  }
  
 /* 
  // Buildings  
  house.ProcessParticles(fluid.particles);
  powerPlant.ProcessParticles(fluid.particles);
  
  house.Draw();
  powerPlant.Draw();

  
  if (house.particleCount >= particleCountThreshold && 
      powerPlant.particleCount >= particleCountThreshold) {
        
    // XXX: Bit of a hack here...
    pushMatrix();    
    
    scale(screen2pixels);
    translate(house.pos.x, house.pos.y);
    scale(house.scale * pixels2screen);
    
    image(lights, 0, 0);
    
    popMatrix();
    
    congratsCounter += timer.GetElapsedTime();
    
    if (congratsCounter > congratsTimeout) {
      Reset(); 
    }
  }
      
  // Draw congrats, even if with 0 opacity, to remove fps hit on first render  
  imageMode(CENTER);
  tint(1, pow(congratsCounter * 0.5, 10));
  image(congrats, width * 0.5, height * 0.5, width, height);
  tint(1, 1);
  */
}


void Reset() {
  motionCounter = congratsCounter = 0.0;
 
  fluid.Reset();
 
  house.Reset();
  powerPlant.Reset(); 
  
  int z = int(random(1, 5));
  
  switch (z) {
    case 1:
      house.pos.set(random(zone1[0], zone1[1]), random(zone1[2], zone1[3]));
      powerPlant.pos.set(random(zone3[0], zone3[1]), random(zone3[2], zone3[3]));
      break; 
      
    case 2:
      house.pos.set(random(zone2[0], zone2[1]), random(zone2[2], zone2[3]));
      powerPlant.pos.set(random(zone4[0], zone4[1]), random(zone4[2], zone4[3]));
      break; 
      
    case 3:
      house.pos.set(random(zone3[0], zone3[1]), random(zone3[2], zone3[3]));
      powerPlant.pos.set(random(zone1[0], zone1[1]), random(zone1[2], zone1[3]));
      break; 
      
    case 4:
      house.pos.set(random(zone4[0], zone4[1]), random(zone4[2], zone4[3]));
      powerPlant.pos.set(random(zone2[0], zone2[1]), random(zone2[2], zone2[3]));
      break; 
  }
}


int[] Screen2Pixels(PVector p) {
  return Screen2Pixels(p.x, p.y);   
}

int[] Screen2Pixels(float x, float y) {
  return new int[] { (int)(x * screen2pixels), (int)(y * screen2pixels) };   
}

PVector Pixels2Screen(int x, int y) {
  return new PVector((float)x * pixels2screen, (float)y * pixels2screen);   
}

PVector Pixels2Screen(int[] p) {
  return Pixels2Screen(p[0], p[1]);
}

PVector Pixels2Screen(PVector p) {
  return Pixels2Screen((int)p.x, (int)p.y);
}


void keyPressed() {
  switch (key) {   
    
    // Menu
    case 'm':
      showMenu = !showMenu;
      break;
      
            
   // Time scale
   case 'q':
      timeScale += 0.5;
      break;
      
   case 'a':
      timeScale -= 0.5;
      timeScale = max(timeScale, 0.5);
      break;
   
   
   // Flow
   case 'w':
     source.IncrementFlow();
     break;
     
   case 's':
     source.DecrementFlow();
     break;
     
     
    // Particle radius
    case 'e':
      particleRenderer.SetRadius(particleRenderer.GetRadius() + 0.01);
      break;
      
    case 'd':
      particleRenderer.SetRadius(max(particleRenderer.GetRadius() - 0.01, 0.01)); 
      break;

          
    // Particle opacity
    case 'r':
      particleRenderer.SetOpacity(min(particleRenderer.GetOpacity() + 0.01, 1.0));
      break;
     
    case 'f':
      particleRenderer.SetOpacity(max(particleRenderer.GetOpacity() - 0.01, 0.01));
      break; 
      
      
    // Particle density threshold
    case 't':
      particleRenderer.SetDensityThreshold(min(particleRenderer.GetDensityThreshold() + 0.01, 1.0));
      break;
      
    case 'g':
      particleRenderer.SetDensityThreshold(max(particleRenderer.GetDensityThreshold() - 0.01, 0.01));
      break;   
      
           
    // Particle draw mode
    case 'y':
      particleRenderer.SetDrawMode(min(particleRenderer.GetDrawMode() + 1, 1));
      break;
     
    case 'h':
      particleRenderer.SetDrawMode(max(particleRenderer.GetDrawMode() - 1, 0));
      break;
      
    
    // Distance field down sampling
    case 'o':
      shadowImage.IncreaseDownsampling();
      break;
    
    case 'l':
      shadowImage.DecreaseDownsampling();
      break;  
      
      

case '=':
  fluidParameter++;
  fluidParameter = min(fluidParameter, fluid.GetNumberOfParameters() - 1);
  break;
  
case '-':
  fluidParameter--;
  fluidParameter = max(fluidParameter, 0);
  break;

      
case ']':
  fluid.IncrementParameter(fluidParameter);
  break;     
      
case '[':
  fluid.DecrementParameter(fluidParameter);
  break;
        
   
    // Objects
    case '1':
      shadowImage.AddShape(new Ellipse(Pixels2Screen(mouseX, mouseY), new PVector(1.0, 1.0)));
      break;
      
    case '2':
      shadowImage.AddShape(new Rectangle(Pixels2Screen(mouseX, mouseY), new PVector(1.5, 0.75)));
//shadowImage.AddShape(new Rectangle(Pixels2Screen(mouseX, mouseY), new PVector(1.5, 0.1)));
      break;
      
    case '3':
      shadowImage.AddShape(new Trapezoid(Pixels2Screen(mouseX, mouseY), new PVector(1.5, 0.75), 0.5));
      break;
      
    case '0':
      shadowImage.RemoveShape(Pixels2Screen(mouseX, mouseY));
      break;
      
      
    // Distance field
    case 'z':
      showDistanceField = !showDistanceField;
      break;
      
    
    // Camera
    case 'c':
      shadowImage.ToggleCamera();      
      break;
      
      
    // Camera calibration  
    case 'v':
      if (shadowImage.HasCamera() && shadowImage.GetUseCamera()) {
        calibrate = !calibrate; 
      }
      
      break;
      
    case 'b':
      if (calibrate) {
        shadowImage.GetHomography().ToggleDrawingMode();
      }
      
      break;
      
      
    // Show shadow
    case 'n':
      showShadow = !showShadow;      
      break;
      
    case 'p':
      shadowImage.ToggleUseOldShadow();      
      break;      
      
    
    case '`':
      fluid.useViscoelasticity = !fluid.useViscoelasticity;
      break;
  }
}

void DrawMenu() {
  fill(0);
  
  textAlign(LEFT, TOP);
  text("Controls:\n" +
       "\n" +
       "Time scale:  q / a:  " + timeScale + "\n" +
       "Flow:  w / s:  " + source.flow + "\n" +
       "\n" + 
       "Particle radius:  e / d:  " + particleRenderer.radius + "\n" +
       "Particle opacity:  r / f:  " + particleRenderer.opacity + "\n" +
       "Particle density threshold:  t / g:  " + particleRenderer.densityThreshold + "\n" +
       "Particle draw mode:  y / h:  " + (particleRenderer.drawMode == 0 ? "particles" : "density") + "\n" +
       "\n" +
       "Shadow downsampling:  o / l:  " + shadowImage.GetDownSampling() + "\n" +
       "\n" +
       "Fluid parameter:  - / =:  " + fluid.GetParameterName(fluidParameter) + "\n" +
       "Fluid value:  [ / ]:  " + fluid.GetParameterValue(fluidParameter) + "\n" + 
       "\n" +
       "Objects:  1-9 / 0\n" +
       "\n" +
       "Information:\n" +
       "\n" +
       "Particle count:  " + fluid.particles.size() + "\n" +
//       "Hashed particle count:  " + fluid.hashTable.GetNumberOfParticles() + "\n" +
//       "Hashtable grid cell count:  " + fluid.hashTable.GetNumberOfGridCells() + "\n" +
       "Pair count:  " + fluid.pairs.size() + "\n" +
       "Spring count:  " + fluid.springs.size() + "\n" +
       "FPS:  " + timer.GetFPS() + "\n", 10, 10);
}


void mousePressed() {   
  if (calibrate) {
    shadowImage.GetHomography().MousePressed(mouseX, mouseY);
    return; 
  }
  
  PVector m = Pixels2Screen(mouseX, mouseY);
  
  // Pick source
  if (source.IsInside(m)) {
    moveSource = true;
  }
  else {
    // Pick objects
    shadowImage.PickShapes(m);
  }
  
  oldMouse.set(m.x, m.y);
}

void mouseDragged() {
  if (calibrate) {
    shadowImage.GetHomography().MouseDragged(mouseX, mouseY);
    return; 
  }
  
  PVector m = Pixels2Screen(mouseX, mouseY); 
  PVector v = PVector.sub(m, oldMouse);
  
  if (moveSource == true) {
    source.pos.add(v);
  }
  else {
    shadowImage.MoveCurrentShape(v); 
  }
  
  oldMouse.set(m.x, m.y);
}

void mouseReleased() {
  if (calibrate) {
    shadowImage.GetHomography().MouseReleased();
    return; 
  }
  
  moveSource = false;
  shadowImage.StopMoveShape();
}

void mouseMoved() {
  PVector m = Pixels2Screen(mouseX, mouseY); 
  
  // Pick source
  if (source.IsInside(m)) {
    showSource = true;
  }
  else {
    showSource = false; 
  }
}
