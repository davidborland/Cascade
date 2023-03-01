/*=========================================================================
 
 Name:        ShadowImage.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Pipeline for creating shadow image from video and shapes.
 
=========================================================================*/


// Standard Processing video class
import processing.video.*;


class ShadowImage { 
  private Wedge wedge;
  private List<Shape> shapes;
  private List<PImage> images;
  
  private PGraphics shadow;
  private PGraphics shadow1;
  private PGraphics shadow2;
  private PGraphics currentShadow;
  
  private PImage oldCamera;
  private float cameraDiff;
  
  private boolean useCamera = true;
  
  private Capture camera = null;
  
  private Homography homography = null;
  private boolean calibrate = false;
  private PImage thresholdMask;
  
  private int downSampling = 4;
  
  private boolean useOldShadow = false;
  
  private int currentShape = -1;


  ShadowImage(PApplet applet, boolean useEye) {
    useCamera = false;
    
    // Create shapes object   
    shapes = new ArrayList<Shape>();
    
    // Single wedge shape
    float aspect = (float)width / height;
    float h = 1;
    wedge = new Wedge(screenWidth / 2, screenWidth / aspect - h * 0.4, screenWidth, h);
    
    // Load images
//    LoadImages();
    
    // Initialize camera
    InitializeCamera(applet);
  
    // Set up shadow objects
    SetDownSampling(downSampling);
  }

  
  public PGraphics GetShadow() {
    return shadow; 
  }

  public Homography GetHomography() {
    return homography; 
  }

  public void PickShapes(PVector mousePosition) {    
    for (int i = 0; i < shapes.size(); i++) {
      if (shapes.get(i).IsInside(mousePosition)) {
        currentShape = i;
        break;
      } 
    }
  }
  
  public void MoveCurrentShape(PVector translation) {   
    if (currentShape >= 0) {
      shapes.get(currentShape).Translate(translation);
    } 
  }
  
  public void StopMoveShape() {
    currentShape = -1; 
  }

  public void IncreaseDownsampling() {
    downSampling *= 2;
    SetDownSampling(min(downSampling, width / 8));
  }
  
  public void DecreaseDownsampling() {    
    downSampling /= 2;
    SetDownSampling(max(downSampling, 1)); 
  }

  public void AddShape(Shape s) {
    shapes.add(0, s); 
  }
  
  public void AddImage(int imageIndex, PVector pos) {
    if (imageIndex < images.size()) {
      shapes.add(0, new Image(pos, images.get(imageIndex)));
    } 
  }
  
  public void RemoveShape(PVector pos) {
    for (int i = 0; i < shapes.size(); i++) {
      if (shapes.get(i).IsInside(pos)) {
        shapes.remove(i);
        break;  
      }
    } 
  }
  
  public boolean HasCamera() {
    return camera != null;
  }
  
  public boolean GetUseCamera() {
    return useCamera; 
  }
  
  public void SetUseCamera(boolean use) {
    if (camera != null) {
      useCamera = use;
      
      if (useCamera) {
        camera.start();
      } 
      else {
        camera.stop(); 
      }
    }
  }
  
  public void ToggleCamera() {
    SetUseCamera(!useCamera);
  }
    
  public void ToggleUseOldShadow() {
    useOldShadow = !useOldShadow; 
  }
  
  public int GetDownSampling() {
    return downSampling; 
  }
  
  private void InitializeCamera(PApplet applet) {
    // Use Processing's Capture library
    String[] cameras = Capture.list();
    
    if (cameras.length == 0) {
      println("No camera available.");
    } 
    else {
      println("Available cameras:");
      for (int i = 0; i < cameras.length; i++) {
        println(cameras[i]);
      }
      
//      camera = new Capture(this, cameras[3]);    
//      camera = new Capture(applet, 320, 240, 30);
//    camera = new Capture(applet, 1280, 960, 30);
     camera = new Capture(applet, 160, 120, 30);
  
      
      // XXX: Starting, looping until available, and stopping, is necessary
      // to intialize the camera image size correctly before passing to the 
      // Homography when on my laptop with an external webcam.
      camera.start();
      while(!camera.available()){ 
        camera.read(); 
      }
      camera.stop();
      
      homography = new Homography(camera, width, height);
      
      oldCamera = new PImage(camera.width, camera.height);
    }       
  }

  public void SetDownSampling(int shadowDownSampling) {
    downSampling = shadowDownSampling;
    
    int w = width / downSampling;
    int h = height / downSampling;
    
    
    // Set up buffers for shadow  
    shadow = createGraphics(w, h);  
    shadow.beginDraw();  
    shadow.colorMode(RGB, 1.0); 
    shadow.endDraw(); 
    
    shadow1 = createGraphics(w, h);
    shadow1.beginDraw();  
    shadow1.colorMode(RGB, 1.0);
    shadow1.endDraw(); 
  
    shadow2 = createGraphics(w, h);
    shadow2.beginDraw();  
    shadow2.colorMode(RGB, 1.0);
    shadow2.endDraw(); 
  
    currentShadow = shadow1;
  
    if (camera != null) {
      homography.SetDestinationSize(w, h);
      thresholdMask = new PImage(w, h);
    }
  }
 

  private void LoadImages() {
    File dir = new File(sketchPath + "/data/");
    
    if (!dir.isDirectory()) {
      return; 
    }
    
    File[] files = dir.listFiles();
      
    images = new ArrayList<PImage>();  
    for (int i = 0; i < files.length; i++) {
      PImage image = loadImage(files[i].getName());
      if (image != null) {
        images.add(image);
      }
    }
  }
 
  
  public void DrawHomography() {    
    if (camera != null) {
      if (camera.available()) {
        camera.read();
        camera.loadPixels(); 
      }
    }
    
    homography.Draw(); 
  }
 
  
  public void Update() {  
    // Render objects to buffer
    currentShadow.beginDraw();
  
    currentShadow.background(1.0, 1.0, 1.0, 0.0);
      
    if (useCamera) {    
      if (camera != null) {
        if (camera.available()) {
          camera.read();
          camera.loadPixels(); 
          
          ComputeImageDifference(camera, oldCamera);
          oldCamera.copy(camera, 0, 0, camera.width, camera.height, 0, 0, oldCamera.width, oldCamera.height);
        }
      }
  
      PImage tImage = homography.GetTransformedImage();
     
  //    tImage.filter(THRESHOLD, 0.75);
      tImage.filter(THRESHOLD, 0.5);
      thresholdMask.copy(tImage, 0, 0, tImage.width, tImage.height, 0, 0, tImage.width, tImage.height);
      thresholdMask.filter(INVERT);
     
      tImage.mask(thresholdMask); 
      currentShadow.image(tImage, 0, 0);
    }
   
    currentShadow.pushMatrix();
    currentShadow.scale(screen2pixels / downSampling);
    
    // Render objects
    wedge.Draw(currentShadow);
    for (int i = 0; i < shapes.size(); i++) {
      shapes.get(i).Draw(currentShadow); 
    } 
    
    currentShadow.popMatrix();
    
    currentShadow.endDraw();
    
  
    // XXX: Can optimize by combining shadow with currentShadow???
    
  
    if (useOldShadow) {  
      shadow.beginDraw();
      
      shadow.background(1.0, 1.0, 1.0, 0.0);
      shadow.image(shadow1, 0, 0);
      shadow.image(shadow2, 0, 0);
      
      shadow.endDraw();
    
      currentShadow = currentShadow == shadow1 ? shadow2 : shadow1;
    }
    else {
      shadow.beginDraw();
      
      shadow.background(1.0, 1.0, 1.0, 0.0);
      shadow.image(currentShadow, 0, 0);
      
      shadow.endDraw(); 
    }
  
/*  
for (int i = 0; i < 5; i++) {
  shadow.filter(ERODE);
} 
 }
 
 
 
   
/*  
  if (shadowDownSampling > 1) {
    // Copy the shadow to the distance field image and downsample.  Lots of room for optimization here...
    distanceFieldImage = new PImage(width, height); 
    distanceFieldImage.copy(shadow, 0, 0, width, height, 0, 0, width, height);
    distanceFieldImage.resize(width / shadowDownSampling, 0);
    
    // Compute distance field
    distanceField.GenerateDF(distanceFieldImage, true);
  }
  else {
    // Compute distance field
    distanceField.GenerateDF(shadow, true);
  }
  
  if (showDistanceField) {
    distanceFieldImage = new PImage(width / shadowDownSampling, height / shadowDownSampling);
    distanceField.CopyToImage(distanceFieldImage);
  } 
*/

  }

  private void ComputeImageDifference(PImage a, PImage b) {
    int numPix = a.width * a.height;
    int d = 0;
    for (int i = 0; i < numPix; i++) {
       d += abs((a.pixels[i] >> 16 & 0xFF) - (b.pixels[i] >> 16 & 0xFF));
    }
    cameraDiff = (float)d / numPix;
  }
 
  public void DrawShapes() {
    pushMatrix();
    scale(screen2pixels);
    
    // Render objects
    wedge.Draw(g);
    for (int i = 0; i < shapes.size(); i++) {
      shapes.get(i).Draw(g); 
    }
    
    popMatrix(); 
  }
 
  public void DrawOutlines() {    
     pushMatrix();
     scale(screen2pixels);

     wedge.DrawOutline(g);
     for (int i = 0; i < shapes.size(); i++) {
        shapes.get(i).DrawOutline(g);
      } 
      
      popMatrix(); 
  }
 
  public void DrawShadow() {
    tint(1, 1);
    imageMode(CORNER);
    image(shadow, 0, 0, width, height); 
  }
}
