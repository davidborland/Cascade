/*=========================================================================
 
 Name:        Timer.pde
 
 Author:      David Borland, The Renaissance Computing Institute (RENCI)
 
 Copyright:   The Renaissance Computing Institute (RENCI)
 
 Description: Compute frames per second.
 
=========================================================================*/


class Timer {
  private float dt;
  private float fps;
  
  private int oldTime;
    
  private int fpsUpdateTime;
  private int fpsCount;
  private int fpsOldTime;
  
  Timer() {   
    // Initialize oldTime
    oldTime = millis();
    fpsOldTime = oldTime;
    
    // Default to 500 milliseconds for fps update
    fpsUpdateTime = 500; 
    fpsCount = 0;
  }
  
  public void Update() {
    // Compute the elapsed time in seconds
    int newTime = millis();
    dt = (newTime - oldTime) / 1000.0;
    oldTime = newTime;
    
    // Compute the fps
    fpsCount++;
    if (newTime - fpsOldTime > 500) {
      fps = (float)fpsCount / ((newTime - fpsOldTime) / 1000.0);
      fpsOldTime = newTime;
      fpsCount = 0;
    }  
  }
  
  public float GetElapsedTime() {
    return dt;
  }  
  
  public float GetFPS() {
    return fps;
  }   
}
